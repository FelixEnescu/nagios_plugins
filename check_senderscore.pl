#!/usr/bin/perl


package main;

# check_senderscore.pl is a Nagios plugin to score on senderscore.org
#
# Based on check_rbl from Elan Ruusamae <glen@delfi.ee>
# Adapted by FLX f@qsol.ro
#
# Version 0.1.1
#
# 2013-02-12 FLX f@qsol.ro
#	- Corected bug when IP does not have reverse
#
# 2013-02-12 FLX f@qsol.ro
#	- First version
#


use strict;
use warnings;

use Nagios::Plugin 0.31;
use Nagios::Plugin::Getopt;
use Nagios::Plugin::Threshold;
use Nagios::Plugin::Functions;
use Net::DNS;
use Readonly;

our $VERSION = '0.1.0';

Readonly our $DEFAULT_RETRIES       	=> 4;
Readonly our $DEFAULT_QUERY_TIMEOUT 	=> 5;

Readonly our $DEFAULT_SENDERSCORESITE	=> "score.senderscore.com";

Readonly our $DEFAULT_CMDFILE			=> "/var/spool/icinga/cmd/icinga.cmd";
Readonly our $DEFAULT_NAG_SERVICE		=> "Senderscore.org";

# IMPORTANT: Nagios plugins could be executed using embedded perl in this case
#            the main routine would be executed as a subroutine and all the
#            declared subroutines would therefore be inner subroutines
#            This will cause all the global lexical variables not to stay shared
#            in the subroutines!
#
# All variables are therefore declared as package variables...
#

## no critic (ProhibitPackageVars)
our ( $options, $plugin, $threshold, $res);
our ( $ip, $hname, $dom, $ohost ); 
# the script is declared as a package so that it can be unit tested
# but it should not be used as a module
if ( !caller ) {
    run();
}

##############################################################################
# subroutines

##############################################################################
# Usage     : verbose("some message string", $optional_verbosity_level);
# Purpose   : write a message if the verbosity level is high enough
# Returns   : n/a
# Arguments : message : message string
#             level   : options verbosity level
# Throws    : n/a
# Comments  : n/a
# See also  : n/a
sub verbose {

    # arguments
    my $message = shift;
    my $level   = shift;

    if ( !defined $message ) {
        $plugin->nagios_exit( UNKNOWN,
            q{Internal error: not enough parameters for 'verbose'} );
    }

    if ( !defined $level ) {
        $level = 0;
    }

    if ( $level < $options->verbose || $options->debug) {
        if ( !print $message ) {
            $plugin->nagios_exit( UNKNOWN, 'Error: cannot write to STDOUT' );
        }
    }

    return;

}

##############################################################################
# Usage     : run();
# Purpose   : main method
# Returns   : n/a
# Arguments : n/a
# Throws    : n/a
# Comments  : n/a
# See also  : n/a
sub run {

    ################################################################################
    # Initialization

    $plugin = Nagios::Plugin->new( shortname => 'SENDERSCORE' );

    my $time = time;

    ########################
    # Command line arguments

    $options = Nagios::Plugin::Getopt->new(
        usage   => 'Usage: %s [OPTIONS]',
        version => $VERSION,
        url     => 'https://github.com/felixenescu/nagios_plugins',
        blurb   => 'Check senderscore.org status',
    );

    $options->arg(
        spec     => 'critical|c=i',
        help     => 'Score for a critical warning if lower',
        required => 0,
        default  => 50,
    );

    $options->arg(
        spec     => 'warning|w=i',
        help     => 'Score for a warning if lower',
        required => 0,
        default  => 80,
    );

    $options->arg(
        spec     => 'debug|d',
        help     => 'Prints debugging information',
        required => 0,
        default  => 0,
    );

    $options->arg(
        spec     => 'host|H=s',
        help     => 'SMTP server to check',
        required => 1,
    );

     $options->arg(
        spec     => 'pasive|p',
        help     => 'Submit a pasive check result to Nagios/Icinga',
        required => 0,
        default  => 0,
    );
	
    $options->arg(
        spec     => 'cmdfile|c=s',
        help     => 'Nagios/Icinga command file',
        required => 0,
		default  => $DEFAULT_CMDFILE,
    );

	$options->arg(
        spec     => 'nag_host|n=s',
        help     => 'Hostname as configured in Nagios/Icinga',
        required => 0,
    );
	
	$options->arg(
        spec     => 'nag_service|g=s',
        help     => 'Service description as configured in Nagios/Icinga',
        required => 0,
 		default  => $DEFAULT_NAG_SERVICE,
	);
	
   $options->arg(
        spec     => 'retry|r=i',
        help     => 'Number of times to try a DNS query (default is 4) ',
        required => 0,
        default  => $DEFAULT_RETRIES,
    );

    $options->arg(
        spec     => 'query-timeout=i',
        help     => 'Timeout of the RBL queries',
        required => 0,
        default  => $DEFAULT_QUERY_TIMEOUT,
    );

    $options->getopts();

    ###############
    # Sanity checks
	
    my $debug   = $options->debug();
	$ohost = $options->host;
	
	
    if ( $options->critical > $options->warning ) {
        $plugin->nagios_exit( UNKNOWN,
            'critical has to be smaller or equal warning' );
    }
	
	if ( $options->pasive ) {
		if ( !$options->nag_host) {
			$plugin->nagios_exit( UNKNOWN,
				'Hostname configured in Nagios/Icinga must be provided in pasive mode' );
		}
		if ( !$options->nag_service) {
			$plugin->nagios_exit( UNKNOWN,
				'Service description configured in Nagios/Icinga must be provided in pasive mode' );
		}		
    }

    $res = Net::DNS::Resolver->new();

    if ( $res->can('force_v4') ) {
        $res->force_v4(1);
    }

    $res->retry( $options->retry() );

    $ip = $ohost;
	
	
    if ( $ip =~ m/[[:lower:]]/mxs ) {
		# Got hostname
		
		$hname = $ip; # keep hostname
		$ip = undef;
		
		my $ans = $res->query($ip);
		if ($ans) {
			foreach my $rr ( $ans->answer ) {
				if ( !( $rr->type eq 'A' ) ) {
					next;
				}
				$ip = $rr->address;

				# take just the first answer
				last;
			}
		} else {
			if ($debug) {
				## no critic (RequireCheckedSyscall)
				print 'DEBUG: no answer: ' . $res->errorstring() . "\n";
			}
		}		

    } else {
		# Got an IP address -> resolve to a domain
		
		my $ans = $res->query($ip);
		if ($ans) {
			foreach my $rr ( $ans->answer ) {
				## no critic(ProhibitDeepNests)
				if ( !( $rr->type eq 'PTR' ) ) {
					next;
				}
				$hname = $rr->ptrdname;

				# take just the first answer
				last;
			}
		} else {
			$hname = "";
			if ($debug) {
				print 'DEBUG: no answer: ' . $res->errorstring() . "\n";
			}
		}
	}
	verbose "Checking $hname ($ip).\n";


    if ( !$ip ) {
        $plugin->nagios_exit( UNKNOWN, 'Cannot resolve ' . $ohost );
    }

    verbose 'Using ' . $options->timeout . " as global script timeout\n";
    alarm $options->timeout;

    ################
    # Set the limits

    $threshold = Nagios::Plugin::Threshold->set_thresholds(
        warning  => '@' . $options->critical . ':' . $options->warning,
        critical => '@0:' . $options->critical,
    );

    ################################################################################
	# Do magic :-)
	( my $qry = $ip ) =~ s/(\d{1,3}) [.] (\d{1,3}) [.] (\d{1,3}) [.] (\d{1,3})/$4.$3.$2.$1.$DEFAULT_SENDERSCORESITE/mxs;
	
	my $ans = $res->query($qry);
	my $tmp; 
	if ($ans) {
		foreach my $rr ( $ans->answer ) {
			if ( !( $rr->type eq 'A' ) ) {
				next;
			}
			$tmp = $rr->address;

			# take just the first answer
			last;
		}
	} else {
		$plugin->nagios_exit( UNKNOWN, 'No answer from senderscore.org: ' . $res->errorstring() );

		if ($debug) {
			print 'DEBUG: no answer: ' . $res->errorstring() . "\n";
		}
	}
	( my $score = $tmp ) =~ s/(\d{1,3}) [.] (\d{1,3}) [.] (\d{1,3}) [.] (\d{1,3})/$4/mxs;
	verbose "Score $score from answer $tmp.\n";
	
	my $status = "$score for $hname ($ip) on $DEFAULT_SENDERSCORESITE";
	
	$plugin->add_perfdata(
		label     => 'score',
		value     => $score,
		uom       => q{},
		threshold => $threshold,
	);
	
    $plugin->add_perfdata(
        label => 'time',
        value => time - $time,
        uom   => q{s},
    );
	
	if ( $options->pasive ) {
	
		Nagios::Plugin::Functions::_fake_exit(1);
		my $e = $plugin->nagios_exit( $threshold->get_status($score), $status );
		
		#print "=msg=" . $e->message . "==\n";
		#print "=code=" . $e->return_code . "==\n";
		my $cmdfile = $options->cmdfile;
		
		my $cmdline = "[" . time() . "] PROCESS_SERVICE_CHECK_RESULT;";
		$cmdline .= 
			  $options->nag_host . ";"
			. $options->nag_service . ";"
			. $e->return_code . ";"
			. $e->message;
		
		#open( FILE, "|" . $options->cmdfile ) or 			$plugin->nagios_exit( UNKNOWN, 'Cannot open cmd file ' . $options->cmdfile . ' for append: '. $! );
		#print FILE $cmdline or 			$plugin->nagios_exit( UNKNOWN, 'Cannot write to cmd file ' . $options->cmdfile . ' : '. $! );
		#close FILE ;
		my $result = `/bin/echo "$cmdline" >> $cmdfile`;
		#print "=cmd=" . $cmdline . "==\n";

	} else {
		$plugin->nagios_exit( $threshold->get_status($score), $status );
	}
    return;

}

1;
