#!/usr/bin/env perl
###########################################################################
# Changes:
#   2014-08-05 Fixed site list in category_to_* functions, avoid STDOUT (JP)
###########################################################################
use    strict;
use    DBI;
use    POSIX;
use    Date::Manip;
use    Getopt::Long;
use    DBD::Pg;
use    Text::CSV_XS;

my $DBUSER = 'info_services';
#my $DBPASS = '5rtf2qaw'; 
my $DBPASS = '8wASpHTC';

# URL to see info on the web
#my $NewsBaseURL = 'http://xsede-news.sdsc.edu/view-item.php?item=';
# Replaced above on 5/8/2012, JP
my $NewsBaseURL = 'https://www.xsede.org/news/user-news/-/news/item/';
# Interval to subtract for recent outages
my $recentInterval = "INTERVAL '7 DAY'";

# DB Connection String
#my $pg_service = 'dbi:Pg:dbname=xsede_user_news;host=tgcdb.xsede.org;port=5432;sslmode=prefer';
# Replaced above on 5/8/2012, JP
my $pg_service = 'dbi:Pg:dbname=teragrid;host=tgcdb.xsede.org;port=5432;sslmode=prefer';

# SQL Query Strings

# Selects outages with an end date in the future, this will include current outages
my $futureOutageQuery = "SELECT i.item_id, i.subject, i.content, 
               to_char(s.event_start_time,'YYYYMMDD HH24:MI:SS'), 
               to_char(s.event_end_time,'YYYYMMDD HH24:MI:SS'), 
               s.event_time_zone, s.update_id, c.category_name
         FROM  user_news.item i
         JOIN  user_news.system_event s ON (s.item_id = i.item_id)
         JOIN  user_news.item_category ic ON (ic.item_id = i.item_id)
         JOIN  user_news.category c ON (c.category_id = ic.category_id)
         WHERE i.item_type = 'S' AND
               i.deleted IS NULL AND
               c.active = 't' AND
                (SELECT s.event_start_time AT time zone 'UTC') > CURRENT_TIMESTAMP(0) AND
               (SELECT s.event_end_time AT time zone 'UTC') >= CURRENT_TIMESTAMP(0) AND
               s.update_id = (SELECT MAX(se.update_id) FROM user_news.system_event se WHERE se.item_id = i.item_id)
         ORDER BY s.event_start_time, i.item_id";
# Removed 3/2/2010 by JP Navarro
#              s.outage_type_id = '2' AND

# Selects current outages (with start in the past and end in the future)
my $currentOutageQuery = "SELECT i.item_id, i.subject, i.content, 
               to_char(s.event_start_time,'YYYYMMDD HH24:MI:SS'), 
               to_char(s.event_end_time,'YYYYMMDD HH24:MI:SS'), 
               s.event_time_zone, s.update_id, c.category_name
         FROM  user_news.item i
         JOIN  user_news.system_event s ON (s.item_id = i.item_id)
         JOIN  user_news.item_category ic ON (ic.item_id = i.item_id)
         JOIN  user_news.category c ON (c.category_id = ic.category_id)
         WHERE i.item_type = 'S' AND
               i.deleted IS NULL AND
               c.active = 't' AND
               (SELECT s.event_start_time AT time zone 'UTC')<= CURRENT_TIMESTAMP(0) AND
               (SELECT s.event_end_time AT time zone 'UTC')>= CURRENT_TIMESTAMP(0) AND
               s.update_id = (SELECT MAX(se.update_id) FROM user_news.system_event se WHERE se.item_id = i.item_id)
         ORDER BY s.event_start_time, i.item_id";
# Removed 3/2/2010 by JP Navarro
#              s.outage_type_id = '2' AND

# Selects outages with end time in the past
my $recentOutageQuery = "SELECT i.item_id, i.subject, i.content, 
               to_char(s.event_start_time,'YYYYMMDD HH24:MI:SS'), 
               to_char(s.event_end_time,'YYYYMMDD HH24:MI:SS'), 
               s.event_time_zone, s.update_id, c.category_name
         FROM  user_news.item i
         JOIN  user_news.system_event s ON (s.item_id = i.item_id)
         JOIN  user_news.item_category ic ON (ic.item_id = i.item_id)
         JOIN  user_news.category c ON (c.category_id = ic.category_id)
         WHERE i.item_type = 'S' AND
               i.deleted IS NULL AND
               c.active = 't' AND
               (SELECT s.event_end_time AT time zone 'UTC') >= (CURRENT_TIMESTAMP(0) - $recentInterval) AND
               (SELECT s.event_end_time AT time zone 'UTC') < CURRENT_TIMESTAMP(0) AND
               s.update_id = (SELECT MAX(se.update_id) FROM user_news.system_event se WHERE se.item_id = i.item_id)
         ORDER BY s.event_start_time, i.item_id";
# Removed 3/2/2010 by JP Navarro
#              s.outage_type_id = '2' AND

# Selects all outages
my $allOutageQuery = "SELECT i.item_id, i.subject, i.content, 
               to_char(s.event_start_time,'YYYYMMDD HH24:MI:SS'), 
               to_char(s.event_end_time,'YYYYMMDD HH24:MI:SS'), 
               s.event_time_zone, s.update_id, c.category_name, s.outage_type_id
         FROM  user_news.item i
         JOIN  user_news.system_event s ON (s.item_id = i.item_id)
         JOIN  user_news.item_category ic ON (ic.item_id = i.item_id)
         JOIN  user_news.category c ON (c.category_id = ic.category_id)
         WHERE i.item_type = 'S' AND
               i.deleted IS NULL AND
               c.active = 't' AND
               s.update_id = (SELECT MAX(se.update_id) FROM user_news.system_event se WHERE se.item_id = i.item_id)
         ORDER BY s.event_start_time, i.item_id";
# Removed 3/2/2010 by JP Navarro
#              s.outage_type_id = '2' AND

my $allUpdateQuery = "SELECT u.item_id, u.update_id, to_char(u.update_date,'YYYYMMDD HH24:MI:SS'), u.content
         FROM user_news.item_update u
         WHERE u.item_id in (
                 SELECT i.item_id FROM  user_news.item i
                   JOIN  user_news.system_event s ON (s.item_id = i.item_id)
                   JOIN  user_news.item_category ic ON (ic.item_id = i.item_id)
                   JOIN  user_news.category c ON (c.category_id = ic.category_id)
                   WHERE i.item_type = 'S' AND
                         i.deleted IS NULL AND
                         c.active = 't' AND
                         s.update_id = (SELECT MAX(se.update_id) FROM user_news.system_event se WHERE se.item_id = i.item_id)
                           )";
#


# Debug setting
my $FALSE  = 0;
my $TRUE   = 1;
my $DEBUG  = $FALSE;

# Outage fields value examples:
#          '4312',
#          'Cobalt in production 8:30PM,',
#          'Cobalt will be unavailable from noon to 6pm on October 22 for emergency filesystem maintenance.',
#          '2009-10-22 12.00.00 PM',
#          '2009-10-22 08.30.00 PM',
#          'CDT',
#          '1',
#          'cobalt.ncsa.teragrid.org',
#          'Partial'

# Update fields value examples:
#          '4312',
#          '2',
#          '2009-10-22 05.30.00 PM',
#          'Returned to service early at 5pm on October 22',

# Use table field indexes to make code more readable
my $F_item_id     = 0;
my $F_subject     = 1;
my $F_content     = 2;
my $F_start_time  = 3;
my $F_end_time    = 4;
my $F_time_zone   = 5;
my $F_update_id   = 6;
my $F_category    = 7;
my $F_outage_type_id = 8;

my ($cache_dir);
GetOptions ('cache|c=s'   => \$cache_dir);
unless ($cache_dir) {
   print STDERR "Cache directory not specified\n";
   exit 1;
}

my $dbh = dbconnect();
my $timestamp = strftime "%Y-%m-%dT%H:%M:%SZ", gmtime;
my @futureOut = dbexecsql($dbh, $futureOutageQuery);
my @recentOut = dbexecsql($dbh, $recentOutageQuery);
my @currentOut = dbexecsql($dbh, $currentOutageQuery);
my @allOut = dbexecsql($dbh, $allOutageQuery);
my @allUpdate = dbexecsql($dbh, $allUpdateQuery);
dbdisconnect($dbh);

my $lock_file = "$cache_dir/.lock";
create_lock($lock_file);

#XMLoutput('future', @futureOut);
#CSVoutput('future', @futureOut);
#XMLoutput('recent', @recentOut);
#CSVoutput('recent', @recentOut);
#XMLoutput('current', @currentOut);
#CSVoutput('current', @currentOut);
#XMLoutput('all', @allOut);
CSVoutput('all', @allOut);
CSVoutput('update', @allUpdate);

delete_lock($lock_file);

exit(0);

####################################################
# Database Access Subroutines
####################################################
sub dbdisconnect {
   my $dbh = shift;
   my $retval;
   eval { $retval = $dbh->disconnect; };
   if ( $@ || !$retval ) {
      dberror( "Error disconnecting from database", $@ || $DBI::errstr );
   }
}

sub dbconnect {
   # I'm using RaiseError because bind_param is too stupid to do
   # anything else, so this allows consistency at least.
   my %args = ( PrintError => 0, RaiseError => 1 );

   debug("connecting to $pg_service");

   my $dbh = DBI->connect("$pg_service", "$DBUSER", "$DBPASS") ||
      die "Database connect err: $DBI::errstr";

   dberror( "Can't connect to database: ", $DBI::errstr ) unless ($dbh);
#  $dbh->do("SET client_min_messages TO debug") if ( $DEBUG );

   return $dbh;
}

# Execute sql statements.
#
# If called in a list context it will return all result rows.
# If called in a scalar context it will return the last result row.
#
sub dbexecsql {
   my $dbh      = shift;
   my $sql      = shift;
   my $arg_list = shift;

   my ( @values, $result );
   my $i      = 0;
   my $retval = -1;
   my $prepared_sql;

   eval {
      debug("SQL going in=$sql");
      $prepared_sql = $dbh->prepare($sql);

      #or die "$DBI::errstr\n";

      $i = 1;
      foreach my $arg (@$arg_list) {
         $arg = '' unless $arg;
         $prepared_sql->bind_param( $i, $arg );

         #or die "$DBI::errstr\n";
         debug("arg ($i) = $arg");
         $i++;
      }
      $prepared_sql->execute;

      #or die "$DBI::errstr\n";

      @values = ();
      while ( $result = $prepared_sql->fetchrow_arrayref ) {
         push( @values, [@$result] );
         foreach (@$result) { $_ = '' unless defined($_); }
         debug( "result row: ", join( ":", @$result ), "" );
      }
   };

   if ($@) { dberror($@); }

   #   debug("last result = ",$values[-1],"");
   debug( "wantarray = ", wantarray, "" );

   return wantarray ? @values : $values[-1];
}

################################################################################
# DB Functions
sub error {
   print STDERR join( '', "ERROR: ", @_, "\n" );
   exit(1);
}

sub dberror {
   my ( $errstr,  $msg );
   my ( $package, $file, $line, $junk ) = caller(1);

   if ( @_ > 1 ) { $msg = shift; }
   else { $msg = "Error accessing database"; }

   $errstr = shift;

   print STDERR "$msg (at $file $line): $errstr\n";
   exit(0);
}

sub debug {
   return unless ($DEBUG);
   my ( $package, $file, $line ) = caller();
   print STDERR join( '', "DEBUG (at $file $line): ", @_, "\n" );
}

###############################################################################
# Lock functions
sub create_lock($) {
   my $lockfile = shift;

   unless (-e $lockfile) {
     write_lock($lockfile);
     return;
   }

   unless ( open (LOCKPID, "<$lockfile") ) {
     write_lock($lockfile);
     return;
   }

   my $lockpid = <LOCKPID>;
   close(LOCKPID);
   unless ( $lockpid ) {               # No pid, full disk perhaps, continue
     print STDERR "Found lock file '$lockfile' and NULL pid, continuing\n";
     write_lock($lockfile);
     return;
   }

   if ( kill 0 => $lockpid ) {
      chomp $lockpid;
      print STDERR "Found lock file '$lockfile' and active process '$lockpid', quitting\n";
      exit 1;
   }

   chomp $lockpid;
   print STDERR "Removing lock file '$lockfile' for INACTIVE process '$lockpid'\n";
   write_lock($lockfile);
}

sub write_lock($) {
   my $lockfile = shift;
   open(LOCK, ">$lockfile") or
      die "Error opening lock file '$lockfile': $!";
   print LOCK "$$\n";
   close(LOCK) or
      die "Error closing lock file '$lockfile': $!";
}

sub delete_lock($) {
   my $lockfile = shift;
   if ((unlink $lockfile) != 1) {
      print STDERR "Failed to delete lock '$lockfile', quitting\n";
      exit 1;
   }
}

###############################################################################
sub category_to_siteid {
   my $in = shift;
   if ( $in =~ /(.*)-(gatech|ncsa|nics|osg|psc|purdue|sdsc|tacc)$/ ) {
      #return($2 . '.teragrid.org'); 
      return($2 . '.xsede.org'); 
   } elsif ( $in =~ /(.*)-(iu)$/ ) {
      #return($2 . '.teragrid.org'); 
      return($2 . '.xsede.org'); 
   }
   return('xes.xsede.org');
}

###############################################################################
sub category_to_resourceid {
   my $in = shift;
   if ( $in =~ /(.*)-(gatech|ncsa|nics|osg|psc|purdue|sdsc|tacc)$/ ) {
      #return($1 . '.' . $2 . '.teragrid.org'); 
      return($1 . '.' . $2 . '.xsede.org'); 
   } elsif ( $in =~ /(.*)-(iu)$/ ) {
      return($1 . '.' . $2 . '.xsede.org'); 
   } elsif ( $in eq 'data-replication-service-xsede-wide' ) {
      return('data-replication-service.xes.xsede.org'); 
   }
   return($in . '.xes.xsede.org');
}

###############################################################################
sub noltgt { #Convert < and > to &lt; and &gt;
   my $line = shift;
   $line =~ s/</&lt;/g;
   $line =~ s/>/&gt;/g;
   return($line);
}

###############################################################################
sub XMLoutput($@) {
   my $type = shift;
   my $cache_file = "$cache_dir/$type" . "OutageReport.xml";
   open(OUT, ">$cache_file.NEW") or
      die "Failed to open output '$cache_file'";

   print OUT '<?xml version="1.0" encoding="UTF-8" ?>' . "\n";
   print OUT "<V4OutageRP Timestamp=\"$timestamp\">\n";
   foreach my $entry (@_) {
#     my @site = split(/\./,$entry->[$F_category]);
#     shift @site;
    
      my $sdate   = ParseDate($entry->[$F_start_time]);
      my $edate   = ParseDate($entry->[$F_end_time]);
      #my $startTS = UnixDate(Date_ConvTZ($sdate,$entry->[$F_time_zone],'UTC'), "%Y-%m-%dT%H:%M:%SZ");
      #my $endTS   = UnixDate(Date_ConvTZ($edate,$entry->[$F_time_zone],'UTC'), "%Y-%m-%dT%H:%M:%SZ");
      my $startTS = UnixDate($sdate, "%Y-%m-%dT%H:%M:%SZ");
      my $endTS   = UnixDate($edate, "%Y-%m-%dT%H:%M:%SZ");


      print OUT "  <Outage>\n";
      print OUT "    <WebURL>$NewsBaseURL$entry->[$F_item_id]</WebURL>\n";
      print OUT "    <Subject>" . noltgt($entry->[$F_subject]) . "</Subject>\n";
      print OUT "    <Content>" . noltgt($entry->[$F_content]) . "</Content>\n";
      print OUT "    <OutageStart>$startTS</OutageStart>\n";
      print OUT "    <OutageEnd>$endTS</OutageEnd>\n";
#     print OUT "    <ResourceID>$entry->[$F_category]</ResourceID>\n";
#     my @site = split(/\./,$entry->[$F_category]);
#     shift @site;
#     print OUT "    <SiteID>" . join('.', @site) . "</SiteID>\n";
      print OUT "    <ResourceID>" . category_to_resourceid($entry->[$F_category]) . "</ResourceID>\n";
      print OUT "    <SiteID>" . category_to_siteid($entry->[$F_category]) . "</SiteID>\n";
      print OUT "  </Outage>\n";
   }
   print OUT "</V4OutageRP>\n";
   close(OUT);

   my @outstat = stat("$cache_file.NEW");
   if ($outstat[7] != 0) {
      system("mv $cache_file.NEW $cache_file");
  }
}

###############################################################################
sub CSVoutput($@) {
   my $type = shift;
   my $cache_file = "$cache_dir/$type" . "OutageReport.csv";
   open my $OUT, ">$cache_file.NEW" or
      die "Failed to open output '$cache_file'";

   my $csv = Text::CSV_XS->new( { binary => 1, eol => $/ } );

   my %outageTypeMap = (
	"1" => "Partial",
	"2" => "Full",
	);

   $csv->print ($OUT, ['OutageID', 'ResourceID', 'WebURL', 'Subject', 'Content', 'OutageStart', 'OutageEnd', 'SiteID', 'OutageType']);
   foreach my $entry (@_) {
      my $sdate   = ParseDate($entry->[$F_start_time]);
      my $edate   = ParseDate($entry->[$F_end_time]);
      #my $startTS = UnixDate(Date_ConvTZ($sdate,$entry->[$F_time_zone],'UTC'), "%Y-%m-%dT%H:%M:%SZ");
      #my $endTS   = UnixDate(Date_ConvTZ($edate,$entry->[$F_time_zone],'UTC'), "%Y-%m-%dT%H:%M:%SZ");
      my $startTS = UnixDate($sdate, "%Y-%m-%dT%H:%M:%SZ");
      my $endTS   = UnixDate($edate, "%Y-%m-%dT%H:%M:%SZ");
#     (my $site = $entry->[$F_category])  =~ s/^[^\.]+\.//;
      my $outageType = $outageTypeMap{$entry->[$F_outage_type_id]};
      my $output = [ $entry->[$F_item_id],
                     category_to_resourceid($entry->[$F_category]),
                     "$NewsBaseURL$entry->[$F_item_id]", 
                     $entry->[$F_subject],
                     $entry->[$F_content],
                     $startTS,
                     $endTS,
                     category_to_siteid($entry->[$F_category]),
                     $outageType
                  ];

      $csv->print ($OUT, $output );
   }
   close($OUT);
   my @outstat = stat("$cache_file.NEW");
   if ($outstat[7] != 0) {
      system("mv $cache_file.NEW $cache_file");
  }
}
