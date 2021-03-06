#!perl -w
package version;

use 5.005_04;
use strict;

use vars qw(@ISA $VERSION $CLASS $STRICT $LAX *declare *qv);

$VERSION = 0.97;

$CLASS = 'version';

#--------------------------------------------------------------------------#
# Version regexp components
#--------------------------------------------------------------------------#

# Fraction part of a decimal version number.  This is a common part of
# both strict and lax decimal versions

my $FRACTION_PART = qr/\.[0-9]+/;

# First part of either decimal or dotted-decimal strict version number.
# Unsigned integer with no leading zeroes (except for zero itself) to
# avoid confusion with octal.

my $STRICT_INTEGER_PART = qr/0|[1-9][0-9]*/;

# First part of either decimal or dotted-decimal lax version number.
# Unsigned integer, but allowing leading zeros.  Always interpreted
# as decimal.  However, some forms of the resulting syntax give odd
# results if used as ordinary Perl expressions, due to how perl treats
# octals.  E.g.
#   version->new("010" ) == 10
#   version->new( 010  ) == 8
#   version->new( 010.2) == 82  # "8" . "2"

my $LAX_INTEGER_PART = qr/[0-9]+/;

# Second and subsequent part of a strict dotted-decimal version number.
# Leading zeroes are permitted, and the number is always decimal.
# Limited to three digits to avoid overflow when converting to decimal
# form and also avoid problematic style with excessive leading zeroes.

my $STRICT_DOTTED_DECIMAL_PART = qr/\.[0-9]{1,3}/;

# Second and subsequent part of a lax dotted-decimal version number.
# Leading zeroes are permitted, and the number is always decimal.  No
# limit on the numerical value or number of digits, so there is the
# possibility of overflow when converting to decimal form.

my $LAX_DOTTED_DECIMAL_PART = qr/\.[0-9]+/;

# Alpha suffix part of lax version number syntax.  Acts like a
# dotted-decimal part.

my $LAX_ALPHA_PART = qr/_[0-9]+/;

#--------------------------------------------------------------------------#
# Strict version regexp definitions
#--------------------------------------------------------------------------#

# Strict decimal version number.

my $STRICT_DECIMAL_VERSION =
    qr/ $STRICT_INTEGER_PART $FRACTION_PART? /x;

# Strict dotted-decimal version number.  Must have both leading "v" and
# at least three parts, to avoid confusion with decimal syntax.

my $STRICT_DOTTED_DECIMAL_VERSION =
    qr/ v $STRICT_INTEGER_PART $STRICT_DOTTED_DECIMAL_PART{2,} /x;

# Complete strict version number syntax -- should generally be used
# anchored: qr/ \A $STRICT \z /x

$STRICT =
    qr/ $STRICT_DECIMAL_VERSION | $STRICT_DOTTED_DECIMAL_VERSION /x;

#--------------------------------------------------------------------------#
# Lax version regexp definitions
#--------------------------------------------------------------------------#

# Lax decimal version number.  Just like the strict one except for
# allowing an alpha suffix or allowing a leading or trailing
# decimal-point

my $LAX_DECIMAL_VERSION =
    qr/ $LAX_INTEGER_PART (?: \. | $FRACTION_PART $LAX_ALPHA_PART? )?
	|
	$FRACTION_PART $LAX_ALPHA_PART?
    /x;

# Lax dotted-decimal version number.  Distinguished by having either
# leading "v" or at least three non-alpha parts.  Alpha part is only
# permitted if there are at least two non-alpha parts. Strangely
# enough, without the leading "v", Perl takes .1.2 to mean v0.1.2,
# so when there is no "v", the leading part is optional

my $LAX_DOTTED_DECIMAL_VERSION =
    qr/
	v $LAX_INTEGER_PART (?: $LAX_DOTTED_DECIMAL_PART+ $LAX_ALPHA_PART? )?
	|
	$LAX_INTEGER_PART? $LAX_DOTTED_DECIMAL_PART{2,} $LAX_ALPHA_PART?
    /x;

# Complete lax version number syntax -- should generally be used
# anchored: qr/ \A $LAX \z /x
#
# The string 'undef' is a special case to make for easier handling
# of return values from ExtUtils::MM->parse_version

$LAX =
    qr/ undef | $LAX_DECIMAL_VERSION | $LAX_DOTTED_DECIMAL_VERSION /x;

#--------------------------------------------------------------------------#

{
    local $SIG{'__DIE__'};
    eval "use version::vxs $VERSION";
    if ( $@ ) { # don't have the XS version installed
	eval "use version::vpp $VERSION"; # don't tempt fate
	die "$@" if ( $@ );
	push @ISA, "version::vpp";
	local $^W;
	*version::qv = \&version::vpp::qv;
	*version::declare = \&version::vpp::declare;
	*version::_VERSION = \&version::vpp::_VERSION;
	*version::vcmp = \&version::vpp::vcmp;
	if ($] >= 5.009000) {
	    no strict 'refs';
	    *version::stringify = \&version::vpp::stringify;
	    *{'version::(""'} = \&version::vpp::stringify;
	    *{'version::(<=>'} = \&version::vpp::vcmp;
	    *version::new = \&version::vpp::new;
	    *version::parse = \&version::vpp::parse;
	}
    }
    else { # use XS module
	push @ISA, "version::vxs";
	local $^W;
	*version::declare = \&version::vxs::declare;
	*version::qv = \&version::vxs::qv;
	*version::_VERSION = \&version::vxs::_VERSION;
	*version::vcmp = \&version::vxs::VCMP;
	if ($] >= 5.009000) {
	    no strict 'refs';
	    *version::stringify = \&version::vxs::stringify;
	    *{'version::(""'} = \&version::vxs::stringify;
	    *{'version::(<=>'} = \&version::vxs::VCMP;
	    *version::new = \&version::vxs::new;
	    *version::parse = \&version::vxs::parse;
	}

    }
}

# Preloaded methods go here.
sub import {
    no strict 'refs';
    my ($class) = shift;

    # Set up any derived class
    unless ($class eq 'version') {
	local $^W;
	*{$class.'::declare'} =  \&version::declare;
	*{$class.'::qv'} = \&version::qv;
    }

    my %args;
    if (@_) { # any remaining terms are arguments
	map { $args{$_} = 1 } @_
    }
    else { # no parameters at all on use line
    	%args = 
	(
	    qv => 1,
	    'UNIVERSAL::VERSION' => 1,
	);
    }

    my $callpkg = caller();
    
    if (exists($args{declare})) {
	*{$callpkg.'::declare'} = 
	    sub {return $class->declare(shift) }
	  unless defined(&{$callpkg.'::declare'});
    }

    if (exists($args{qv})) {
	*{$callpkg.'::qv'} =
	    sub {return $class->qv(shift) }
	  unless defined(&{$callpkg.'::qv'});
    }

    if (exists($args{'UNIVERSAL::VERSION'})) {
	local $^W;
	*UNIVERSAL::VERSION 
		= \&version::_VERSION;
    }

    if (exists($args{'VERSION'})) {
	*{$callpkg.'::VERSION'} = \&version::_VERSION;
    }

    if (exists($args{'is_strict'})) {
	*{$callpkg.'::is_strict'} = \&version::is_strict
	  unless defined(&{$callpkg.'::is_strict'});
    }

    if (exists($args{'is_lax'})) {
	*{$callpkg.'::is_lax'} = \&version::is_lax
	  unless defined(&{$callpkg.'::is_lax'});
    }
}

sub is_strict	{ defined $_[0] && $_[0] =~ qr/ \A $STRICT \z /x }
sub is_lax	{ defined $_[0] && $_[0] =~ qr/ \A $LAX \z /x }

1;
