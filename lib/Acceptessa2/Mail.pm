package Acceptessa2::Mail;
use strict;
use warnings;

use Acceptessa2::Mail::Parameter;

use Try::Tiny;
use Encode;
use File::Basename;

use Paws;
use Text::Xslate;
use Email::MIME;
use MIME::Base64;

my $TEMPLATE_BUCKET   = 'acceptessa2-mail-template';
my $ATTACHMENT_BUCKET = 'acceptessa2-mail-attachment';

sub get_template {
    my ($self, $key) = @_;
    my $s3  = Paws->service('S3', region => 'ap-northeast-1');
    my $ret = try {
        my $o = $s3->GetObject(Bucket => $TEMPLATE_BUCKET, Key => $key);
        return $o ? $o->Body : undef;
    }
    catch {
        warn sprintf "template not found: %s (%s:%s)", $key, $_->message, $_->code;
        return;
    };
}

sub get_attachment {
    my ($self, $key) = @_;
    my $s3  = Paws->service('S3', region => 'ap-northeast-1');
    my $ret = try {
        my $o = $s3->GetObject(Bucket => $ATTACHMENT_BUCKET, Key => $key);
        return $o ? $o->Body : undef;
    }
    catch {
        warn sprintf "attachment not found: %s (%s:%s)", $key, $_->message, $_->code;
        return;
    };
}

sub send_mail {
    my ($self, $mail) = @_;
    my $ses = Paws->service('SES', region => 'ap-northeast-1');
    my $ret = try {
        return $ses->SendRawEmail(RawMessage => { Data => encode_base64 $mail->as_string });
    }
    catch {
        warn sprintf "mail send fail: %s (%s:%s)", $_->message, $_->http_status, $_->code;
        return;
    };
}

sub run {
    my ($class, $payload) = @_;
    my $p = try { Acceptessa2::Mail::Parameter->new($payload) } or return { error => 'invalid parameter' };

    ## fetch template
    my $tmpl = $class->get_template($p->template) or return { error => 'template not found' };

    ## render template
    my $err;
    my $tx       = Text::Xslate->new(syntax => 'Metakolon');
    my $rendered = try {
        $tx->render_string($tmpl, $p->data);
    }
    catch {
        $err = $_;
    };

    if ($err) {
        warn "template syntax error: $err";
        return { error => "template syntax error: $err" };
    }

    $rendered =~ s/<!--\s*(.*?)\s+-->\r?\n//;    ## subject get from template's first comment
    my $subject = $1;
    my @mimes;

    push @mimes,
      Email::MIME->create(
        'attributes' => {
            'content_type' => 'text/html',
            'charset'      => 'utf-8',
            'encoding'     => 'base64',
        },
        'body' => encode('utf-8', $rendered),
      );

    ## add attachments if exists
    if (my $attaches = $p->attachment) {
        for my $id (sort keys %$attaches) {
            my $s3key   = $attaches->{$id};
            my $content = $class->get_attachment($s3key) or return { error => "attachment not found: $s3key" };
            my $base    = basename($s3key);

            push @mimes,
              Email::MIME->create(
                header_str => [
                    'Content-Id' => "<$id>",
                ],
                attributes => {
                    content_type => 'image/jpeg',
                    name         => $base,
                    filename     => $base,
                    encoding     => 'base64',
                    disposition  => 'attachment',
                },
                body => $content,
              );
        }
    }

    ## create mail
    my $parent = Email::MIME->create(
        header => [
            'From'    => encode('MIME-Header-ISO_2022_JP', $p->from),
            'To'      => encode('MIME-Header-ISO_2022_JP', $p->to),
            'Subject' => encode('MIME-Header-ISO_2022_JP', $subject),
            $p->cc ? ('Cc' => $p->cc) : (),
        ],
        parts => \@mimes,
    );

    ## send mail
    $class->send_mail($parent);

    return { success => 1 };
}

1;
