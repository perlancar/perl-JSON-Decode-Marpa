package JSON::Decode::Marpa;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use MarpaX::Simple qw(gen_parser);

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(from_json);

my $parser = gen_parser(
    grammar => <<'EOF',
:default     ::= action => do_array

:start       ::= json

json         ::= object action => do_first
               | array action => do_first

object       ::= ('{') members ('}') action => do_hash

members      ::= pair*                 separator => <comma>

pair         ::= string (':') value

value        ::= string action => do_first
               | object action => do_first
               | number action => do_first
               | array action => do_first
               | 'true' action => do_true
               | 'false' action => do_false
               | 'null' action => do_undef


array        ::= ('[' ']')
               | ('[') elements (']') action => do_first

elements     ::= value+                separator => <comma>

number         ~ int
               | int frac
               | int exp
               | int frac exp

int            ~ digits
               | '-' digits

digits         ~ [\d]+

frac           ~ '.' digits

exp            ~ e digits

e              ~ 'e'
               | 'e+'
               | 'e-'
               | 'E'
               | 'E+'
               | 'E-'

string ::= <string lexeme> action => do_string

<string lexeme> ~ quote <string contents> quote
# This cheats -- it recognizers a superset of legal JSON strings.
# The bad ones can sorted out later, as desired
quote ~ ["]
<string contents> ~ <string char>*
<string char> ~ [^"\\] | '\' <any char>
<any char> ~ [\d\D]

comma          ~ ','

:discard       ~ whitespace
whitespace     ~ [\s]+
EOF
    actions => {
        do_array  => sub { shift; [@_] },
        do_hash   => sub { shift; +{map {@$_} @{ $_[0] } } },
        do_first  => sub { $_[1] },
        do_undef  => sub { undef },
        do_string => sub {
            shift;

            my($s) = $_[0];

            $s =~ s/^"//;
            $s =~ s/"$//;

            $s =~ s/\\u([0-9A-Fa-f]{4})/chr(hex($1))/eg;

            $s =~ s/\\n/\n/g;
            $s =~ s/\\r/\r/g;
            $s =~ s/\\b/\b/g;
            $s =~ s/\\f/\f/g;
            $s =~ s/\\t/\t/g;
            $s =~ s/\\\\/\\/g;
            $s =~ s{\\/}{/}g;
            $s =~ s{\\"}{"}g;

            return $s;
        },
        do_true   => sub { 1 },
        do_false  => sub { 0 },
    },
);

sub from_json {
    $parser->(shift);
}

1;
# ABSTRACT: JSON parser using Marpa

=head1 SYNOPSIS

 use JSON::Decode::Marpa qw(from_json);
 my $data = from_json(q([1, true, "a", {"b":null}]));


=head1 DESCRIPTION

This module is based on L<MarpaX::Demo::JSONParser> and makes it more convenient
to use. I packaged this for casual benchmarking against L<Pegex::JSON> and
L<JSON::Decode::Regexp>.

The result on my computer: Pegex::JSON and JSON::Decode::Marpa are roughly the
same speed (but Pegex has a much smaller startup overhead than Marpa).
JSON::Decode::Regexp is about an order of magnitude faster than this module, and
JSON::XS is about I<three orders of magniture> faster. So that's that.


=head1 FUNCTIONS

=head2 from_json($str) => DATA

Decode JSON in C<$str>. Dies on error.


=head1 FAQ


=head1 SEE ALSO

L<JSON>, L<JSON::PP>, L<JSON::XS>, L<JSON::Tiny>, L<JSON::Decode::Regexp>,
L<Pegex::JSON>.

=cut
