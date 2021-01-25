use strict;
use Test::More;
use Test::LongString;
use Acceptessa2::Mail;
use YAML;

sub cr2crlf {
    my $val = shift;
    return join("\r\n", split "\n", $val) . "\r\n";
}

my $data  = YAML::Load(join "", <DATA>);
my @tests = (
    {
        template  => $data->{tmpl1},
        expected  => cr2crlf($data->{result1}),
        desc      => 'basic template',
        parameter => {
            from     => 'from@from',
            to       => 'to@to',
            subject  => 'subject subject',
            template => "z",
            data     => {
                hello => "mogemoge",
                world => "fugafuga",
            }
        },
        ret => { success => 1 },
    },
    {
        template  => $data->{tmpl2},
        expected  => cr2crlf($data->{result2}),
        desc      => 'with attachment',
        parameter => {
            from     => 'from@from',
            to       => 'to@to',
            subject  => 'subject subject',
            template => "z",
            data     => {
                hello => "mogemoge",
                world => "fugafuga",
            },
            attachment => {
                a1 => 'moge/a1.png',
                b1 => 'fuga/b1.png',
            }
        },
        ret => { success => 1 },
    },
    {
        template  => '<: $test ',
        expected  => "",
        desc      => 'with error',
        parameter => {
            from     => 'from@from',
            to       => 'to@to',
            subject  => 'subject subject',
            template => "z",
            data     => {
                hello => "mogemoge",
                world => "fugafuga",
            },
        },
        ret => { error => $data->{error1} },
    },
);

plan tests => @tests * 2;

my $ATTACHMENT = {
    "moge/a1.png" => "aaaaaaaaaa",
    "fuga/b1.png" => "bbbbbbbbbb",
};

local *Email::Simple::Creator::_date_header = sub { 'ThisIsDateString' };
local *Acceptessa2::Mail::get_attachment    = sub {
    my ($class, $key) = @_;
    return $ATTACHMENT->{$key};
};

foreach my $t (@tests) {
    my $result;
    local *Acceptessa2::Mail::get_template = sub { $t->{template} };
    local *Acceptessa2::Mail::send_mail    = sub { $result = $_[1] };

    my $ret           = Acceptessa2::Mail->run($t->{parameter});
    my $mail_contents = $result ? $result->as_string : '';
    is_deeply $ret, $t->{ret}, "$t->{desc}: return value ok";

    if ($t->{parameter}->{attachment}) {
        my $boundary = quotemeta $result->{ct}->{attributes}->{boundary};
        $mail_contents =~ s/$boundary/wawawawawawawawawawa/g;
    }

    is_string $mail_contents, $t->{expected}, "$t->{desc}: template render ok";
}

__DATA__
tmpl1: |
  <!-- subject subject -->
  <: $hello :> <: $world :>
result1: |
  From: from@from
  To: to@to
  Subject: subject subject
  Date: ThisIsDateString
  MIME-Version: 1.0
  Content-Transfer-Encoding: base64
  Content-Type: text/html; charset=utf-8
  
  bW9nZW1vZ2UgZnVnYWZ1Z2EK
tmpl2: |
  <!-- subject2 subject2 -->
  <: $hello :> <: $world :>
result2: |
  From: from@from
  To: to@to
  Subject: subject2 subject2
  Date: ThisIsDateString
  MIME-Version: 1.0
  Content-Transfer-Encoding: 7bit
  Content-Type: multipart/mixed; boundary=wawawawawawawawawawa
  
  
  --wawawawawawawawawawa
  Date: ThisIsDateString
  MIME-Version: 1.0
  Content-Type: text/html; charset=utf-8
  Content-Transfer-Encoding: base64
  
  bW9nZW1vZ2UgZnVnYWZ1Z2EK
  
  --wawawawawawawawawawa
  Content-Id: <a1>
  Date: ThisIsDateString
  MIME-Version: 1.0
  Content-Type: image/jpeg; name=a1.png
  Content-Disposition: attachment; filename=a1.png
  Content-Transfer-Encoding: base64

  YWFhYWFhYWFhYQ==
  
  --wawawawawawawawawawa
  Content-Id: <b1>
  Date: ThisIsDateString
  MIME-Version: 1.0
  Content-Type: image/jpeg; name=b1.png
  Content-Disposition: attachment; filename=b1.png
  Content-Transfer-Encoding: base64
  
  YmJiYmJiYmJiYg==
  
  --wawawawawawawawawawa--
error1: |
  template syntax error: Text::Xslate::Syntax::Kolon: Malformed templates detected, near ' $test ', while parsing templates (<string>:1) at lib/Acceptessa2/Mail.pm line 68.
  ----------------------------------------------------------------------------
  <: $test 
  ----------------------------------------------------------------------------
