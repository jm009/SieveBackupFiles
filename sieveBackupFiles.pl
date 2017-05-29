#!/usr/bin/perl -w

# My backup scripts normaly generate files or directories that contain
# a date string, like backup_YYYY-mm-dd_hh-MM-ss.tar.gz
# There may be a lot of backups, even serveral backup directories
# created per day, created with rsync and hard links.
#
# This script cleans them up, keeps
#   every day for the last two weeks
#   every pair day for the last month
#   every 1st, 9th, 17th and 25th for the last three months
#   every 1st forever
#
# May 27th, 2017
# post@greiner-informatik.de


use strict;
use warnings;
use POSIX;
use File::Path qw(remove_tree);

# Create Testfiles:
# export now=`date +"%s"`
# for ((i=now;i>now-180*$secondsPerDay;i=i-$secondsPerDay)); do touch /tmp/testSieve/test_`date -d @$i +"%Y-%m-%d"`.tar.gz;done

our $now = time();
our $secondsPerDay = 60 * 60 * 24;
our $secondsPerHalfDay = $secondsPerDay / 2;
our $dir;
our $pattern;
our @files;
our $isDirs;
 
sub usage($) {
   my $error = shift;
   print "Clean up backup files or directories. Keep\n";
   print "  every day for the last two weeks\n";
   print "  every pair day for the last month\n";
   print "  every 1st, 9th, 17th and 25th for the last three months\n";
   print "  every 1st forever\n\n";
   print "Usage: SieveBackupFiles <directory> <filepattern> -keepOnlyLastOfDayAfter <n>\n\n";
   print "<filepattern> is a regular expression with named groups 'year', 'month' and 'day'\n";
   print "<n> must be lower than or equal to 14, and for dates older than <n> days, if\n";
   print "there exists more than one backup per day, all backups of this day exept the\n";
   print "last one are deleted.\n\n";
   print "File names are sorted alphabetically to put them in date-time order.\n";
   print "So don't shoot yourself in the foot and let the pattern match differently\n";
   print "formatted names.\n\n";
   print "Usage example: SieveBackupFiles /var/backups/myfiles \\\n";
   print " \"home_(?<year>\\\\d\\\\d\\\\d\\\\d)-(?<month>\\\\d\\\\d)-(?<day>\\\\d\\\\d)_\\\\d\\\\d-\\\\d\\\\d-\\\\d\\\\d\" \\\n";
   print " -keepOnlylastOfDayAfter 10\n\n";
   print "Don't forget to double escape \\ and . (backslashes and dots)\n";
   print "if you call this program from the command line).\n";
   print "Probably it is a good idea to put the pattern in \" (double quotes)\n";
   print "in addition to the double escaping.\n\n";
   print "Error: $error\n";
   exit 1;
}

sub getFileDate($) {
   my $fileName = shift;
   $fileName =~ m/$pattern/;
   my $year = $+{year};
   my $month = $+{month};
   my $day = $+{day};
   if (($year !~ m/^\d\d\d\d$/) || (1970 > $year) || (2100 < $year)) {
       usage("Year must be four digits and must be between 1970 and 2100 (pattern: $pattern, filename: $fileName).");
   }
   if (($month !~ m/^\d\d?$/) || (1 > $month) || (12 < $month)) {
       usage("Month must be one or two digits and must be between 1 and 12 (pattern: $pattern, filename: $fileName).");
   }
   if (($day !~ m/^\d\d?$/) || (1 > $day) || (31 < $day)) {
       usage("Day must be one or two digits and must be between 1 and 31 (pattern: $pattern, filename: $fileName).");
   }
   my $time_t = POSIX::mktime(0, 0, 12, $day, $month - 1, $year - 1900);
   return $time_t;
}

sub deleteFileOrDir($) {
   my $fileName = shift;
   print "Deleting $fileName...\n";
   if ($isDirs) {
      remove_tree("$dir/$fileName");
   }
   else {
      unlink("$dir/$fileName");
   }
}

sub keepOnlyLastOfDay($) {
   my $nbDays = shift;
   my $lastFileName = "";
   my $lastFileDate = -4028402; # random negative number
   my $i = 0;
   my $nbFiles = @files;
   while ($i < $nbFiles) {
      my $fileName = $files[$i];
      my $fileDate = getFileDate($fileName);
      if (($lastFileDate == $fileDate) && ($fileDate + $secondsPerHalfDay < $now - $nbDays * $secondsPerDay)) {
         deleteFileOrDir($lastFileName);
         splice(@files,$i-1,1);
         $nbFiles--;
      }
      else {
         $i++;
      }
      $lastFileDate = $fileDate;
      $lastFileName = $fileName;
   }
}

sub maxDayOfMonth($$) {
   my $year = shift;
   my $month = shift;
   $month++; # Work with readable month values
   if (1 == $month || 3 == $month || 5 == $month || 7 == $month || 8 == $month || 10 == $month || 12 == $month) {
      return 31;
   }
   elsif (2 == $month) {
      if ($year % 400 == 0) {
         return 29;
      }
      elsif ($year % 100 == 0) {
         return 28;
      }
      elsif ($year % 4 == 0) {
         return 29;
      }
      else {
         return 28;
      }
   }
   else {
      return 30;
   }
}

sub min($$) {
   my $a = shift;
   my $b = shift;
   return $a < $b ? $a : $b;
}

sub setDateTimeTo12($) {
   my $dateTime = shift;
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($dateTime);
   return POSIX::mktime(0, 0, 12, $mday, $mon, $year);
}

sub daysToKeep() {
   my $dayCounter = setDateTimeTo12($now);
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($dayCounter);
   $dayCounter = setDateTimeTo12($dayCounter - 14 * $secondsPerDay);
   my @daysToKeep = ($dayCounter);
   if (0 == $mon) {
      $mon = 11;
      $year--;
   }
   else {
      $mon--;
   }
   my $oneMonthAgo = POSIX::mktime(0, 0, 12, min($mday, maxDayOfMonth($year + 1900, $mon)), $mon, $year);
   if (0 == $mon) {
      $mon = 11;
      $year--;
   }
   else {
      $mon--;
   }
   if (0 == $mon) {
      $mon = 11;
      $year--;
   }
   else {
      $mon--;
   }
   my $threeMonthsAgo = POSIX::mktime(0, 0, 12, min($mday, maxDayOfMonth($year + 1900, $mon)), $mon, $year);
   my $twentyYearsAgo = POSIX::mktime(0, 0, 12, 1, 1, $year - 20); 
   for ($dayCounter = setDateTimeTo12($dayCounter - $secondsPerDay); $dayCounter >= $oneMonthAgo; $dayCounter = setDateTimeTo12($dayCounter - $secondsPerDay)) {
      ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($dayCounter);
      if ($mday % 2 == 1) {
         push(@daysToKeep, $dayCounter);
      }
   }
   for ( ; $dayCounter >= $threeMonthsAgo; $dayCounter = setDateTimeTo12($dayCounter - $secondsPerDay)) {
      ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($dayCounter);
      if ($mday % 8 == 1) {
         push(@daysToKeep, $dayCounter);
      }
   }
   for ( ; $dayCounter >= $twentyYearsAgo; $dayCounter = setDateTimeTo12($dayCounter - $secondsPerDay)) {
      ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($dayCounter);
      if ($mday == 1) {
         push(@daysToKeep, $dayCounter);
      }
   }
   return @daysToKeep;
}
   
sub deleteBetweenExceptYoungestAndOldest($$) {
   my $from = shift;
   my $to = shift;
   my $fromString = localtime($from);
   my $toString = localtime($to);
   print "from: $fromString, to: $toString\n";
   my $toKeepOldestIndex = 0;
   while ($toKeepOldestIndex < $#files && getFileDate($files[$toKeepOldestIndex]) < $from - $secondsPerHalfDay) {
      $toKeepOldestIndex++;
   }
   my $toKeepYoungestIndex = $#files;
   while ($toKeepYoungestIndex > 0 && getFileDate($files[$toKeepYoungestIndex]) >= $to + $secondsPerHalfDay) {
      $toKeepYoungestIndex--;
   }
   my $nbFilesToDelete = $toKeepYoungestIndex - $toKeepOldestIndex - 1;
   if ($nbFilesToDelete > 0) {
      my @filesToDelete = splice(@files, $toKeepOldestIndex + 1, $nbFilesToDelete);
      foreach my $fileToDelete (@filesToDelete) {
         deleteFileOrDir($fileToDelete);
      }
   }
}

if (4 != @ARGV) { usage("Exactly four command line parameters expected."); }
$dir = $ARGV[0];
if ( ! -d $dir ) { usage("Command line parameter 1 must be a directory."); }
$pattern = $ARGV[1];
my $regex = eval { qr/$pattern/ };
if ($@) { usage("invalid regex '$pattern': $@"); }
if ( $pattern !~ /\(?(<year>|'year')/ ) { usage("Pattern must contain a named group '(?<year>...)'."); }
if ( $pattern !~ /\(?(<month>|'month')/ ) { usage("Pattern must contain a named group '(?<month>...)'."); }
if ( $pattern !~ /\(?(<day>|'day')/ ) { usage("Pattern must contain a named group '(?<day>...)'."); }
if ("-keepOnlyLastOfDayAfter" ne $ARGV[2]) { usage("Command line parameter 3 must be '-keepOnlyLastOfDayAfter'."); }
my $keepOnlyLastOfDayAfter = $ARGV[3];
if (($keepOnlyLastOfDayAfter !~ /\d\d?/) || ($keepOnlyLastOfDayAfter < 1) || ($keepOnlyLastOfDayAfter > 14)) {
   usage ("Command line parameter 4 must be less than or equal to 14.");
}
opendir(DIR, $dir) || die $!;
my @filesTmp = grep { /^${pattern}$/ } readdir(DIR);
closedir(DIR);
if (0 == @filesTmp) { usage ("Nothing found for $dir/$pattern."); }
if ( -d "$dir/$filesTmp[0]" ) {
   $isDirs = 1; # true
   @files = grep( -d "$dir/$_", @filesTmp);
}
elsif ( -f "$dir/$filesTmp[0]" ) {
   $isDirs = 0; # false
   @files = grep( -f "$dir/$_", @filesTmp);
}
if ($#filesTmp != $#files) { usage("Pattern must match files or directories, not both, and no other type of file system entry."); }
@files = sort @files;
keepOnlyLastOfDay($keepOnlyLastOfDayAfter);
my @daysToKeep = daysToKeep();
for (my $i = 0; $i < $#daysToKeep; $i++) {
   if (@files < 2) {
      print "Less than two files left for cleanup. Exiting...\n";
      return;
   }
   deleteBetweenExceptYoungestAndOldest($daysToKeep[$i + 1], $daysToKeep[$i]);
}


