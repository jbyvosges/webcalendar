#!/usr/bin/perl
# $Id$
#
# This tool will update a translation file by doing the following:
# - Phrases are organized by the page on which they first appear.
# - When a missing translation is found, the phrase can optionally have
#   << MISSING >>
#   right above it. And, when the "phrase" is an abbreviation of the
#   full English text, show the English text (in a comment) below.
#
# Example:
#   << MISSING >>
#   custom-script-help:
#   English text: Allows entry of custom Javascript or stylesheet text that will be inserted into the HTML "head" section of every page.
#
# Note: you will lose any comments you put in the translation file
# when using this tool (except for the comments at the very beginning).
#
# Note #2: This will overwrite the existing translation file, so a backup
# of the original can optionally be saved with a timestamp file extension.
#
# Usage:
# update_translation.pl [-p plugin] languagefile
#
# Example for main WebCalendar translation:
# update_translation.pl French.txt
#    or
# update_translation.pl French
#
# Example for plugin "tnn" translation:
# update_translation.pl -p tnn French.txt
#    or
# update_translation.pl -p tnn French
#
# Note: this utility should be run from this directory (tools).
# Note #2: you can use perltidy to format this perl script nicely:
#  http://perltidy.sourceforge.net/
# Usage:
#  perltidy -i=2 update_translation.pl
#  (which will create update_translation.pl.tdy, the new version)
#
####################################################################
$program_version = 'v1.3.0';
$program_date    = '28 Sep 2008';

use File::Copy;
use File::Find;

sub find_pgm_files {
# Skipping non WebCalendar plugins,
# and the file "includes/js/translate.js.php" which contains duplicates from .js files,
# if the filename ends in .class, .js or .php, add it to @files.
  push( @files, "$File::Find::name" )
    if ( $_ ne 'translate.js.php'
    && $_ =~ /\.(class|js|php)$/i
    && $File::Find::dir !~ /(fckeditor|htmlarea|phpmailer)/i );
}

$base_dir  = '..';
$trans_dir = '../translations';

$base_trans_file = "$trans_dir/English-US.txt";
$plugin          = '';

$save_backup  = 1; # set to 1 to create backups
$show_dups    = 0; # set to 0 to minimize translation file.
$show_missing = 1; # set to 0 to minimize translation file.
$verbose      = 0;

( $this ) = reverse split( /\//, $0 );

for ( $i = 0; $i < @ARGV; $i++ ) {
  if ( $ARGV[ $i ] eq '-p' ) {
    $plugin = $ARGV[ ++$i ];
  }
  elsif ( $ARGV[ $i ] eq '-b' ) {
    $save_backup++;
  }
  elsif ( $ARGV[ $i ] eq '-d' ) {
    $show_dups++;
  }
  elsif ( $ARGV[ $i ] eq '-m' ) {
    $show_missing--;
  }
  elsif ( $ARGV[ $i ] eq '-v' ) {
    $verbose++;
  }
  else {
    $infile = $ARGV[ $i ];
  }
}

die "Usage: $this [-p plugin] language\n" if ( $infile eq '' );

if ( $plugin ne '' ) {
  $p_trans_dir       = "$base_dir/$plugin/translations";
  $p_base_trans_file = "$p_trans_dir/English-US.txt";
  $p_base_dir        = "$base_dir/$plugin";
}
else {
  $p_trans_dir       = $trans_dir;
  $p_base_trans_file = $base_trans_file;
  $p_base_dir        = $base_dir;
}

$infile .= '.txt' if ( $infile !~ /txt$/ );

if ( -f "$trans_dir/$infile" || -f "$p_trans_dir/$infile" ) {
  $b_infile = "$trans_dir/$infile";
  $infile   = "$p_trans_dir/$infile";
}

#print "infile: $infile\nb_infile: $b_infile\ntrans_dir: $trans_dir\n";

die "Usage: $this [-p plugin] language\n" if ( !-f $infile );

print "Translation file: $infile\n" if ( $verbose );

#
# Save a backup copy of old translation file before we mess with it.
#
if ( $save_backup ) {
  $bak = $infile;
  $bak =~ s/txt$//;
  print "Attempting to backup file $infile. ";
  if ( copy( $infile, $bak . ( stat( $infile ) )[9] ) ) {
    print "Success!\n";
  }
  else {
    warn "Failure!:\n$! ";
  }
}

# Read in the plugin base translation file.
if ( $plugin ne '' ) {
  print "Reading plugin base translation file: $p_base_trans_file\n"
    if ( $verbose );
  open( F, $p_base_trans_file ) || die "Error opening $p_base_trans_file";
  while ( <F> ) {
    chop;
    s/\r*$//g; # remove annoying CR
    next if ( /^#/ );
    if ( /\s*:\s*/ ) {
      $abbrev = $`;
      $base_trans{ $abbrev } = $' if ( $abbrev ne 'charset' );
    }
  }
  close( F );
}

# Now load the base translation file (English) so that we can include
# the English text, below the untranslated phrase, in a comment.
open( F, $base_trans_file ) || die "Error opening $base_trans_file";
print "Reading base translation file: $base_trans_file\n" if ( $verbose );
while ( <F> ) {
  chop;
  s/\r*$//g; # remove annoying CR
  next if ( /^#/ );
  if ( /\s*:\s*/ ) {
    $abbrev = $`;
    $base_trans{ $abbrev } = $';
  }
}
close( F );

#
# Now load the translation file we are going to update.
#
if ( -f $infile ) {
  print "Reading current translations from $infile\n" if ( $verbose );
  open( F, $infile ) || die "Error opening $infile";
  $in_header = 1;
  while ( <F> ) {
    chop;
    s/\r*$//g; # remove annoying CR
    if ( $in_header && /^#/ ) {
      if ( /Translation last (pagified|updated)/ ) {
# Ignore since we will replace this with current date below.
      }
      else {
        $header .= $_ . "\n";
      }
    }
    next if ( /^#/ );
    $in_header = 0;
    if ( /\s*:\s*/ ) {
      $abbrev = $`;
      $temp   = $';
      $temp   = '='
        if ( $infile !~ /english-us/i && $base_trans{ $abbrev } eq $temp );
      $trans{ $abbrev } = $temp;
    }
  }
}

$trans{ 'PROGRAM_DATE' }    = $program_date;
$trans{ 'PROGRAM_VERSION' } = $program_version;
$trans{ 'PROGRAM_NAME' }    = $trans{ 'Title' }
 . " $program_version ($program_date)";

$trans{ 'charset' }   = '=' if ( !defined( $trans{ 'charset' } ) );
$trans{ 'direction' } = '=' if ( !defined( $trans{ 'direction' } ) );
$trans{ '__mm__/__dd__/__yyyy__' } = '='
  if ( !defined( $trans{ '__mm__/__dd__/__yyyy__' } ) );
$trans{ '__month__ __dd__' } = '='
  if ( !defined( $trans{ '__month__ __dd__' } ) );
$trans{ '__month__ __dd__, __yyyy__' } = '='
  if ( !defined( $trans{ '__month__ __dd__, __yyyy__' } ) );
$trans{ '__month__ __yyyy__' } = '='
  if ( !defined( $trans{ '__month__ __yyyy__' } ) );

if ( $plugin ne '' ) {
  print "Reading current WebCalendar translations from $b_infile\n"
    if ( $verbose );
  open( F, $b_infile ) || die "Error opening $b_infile";
  $in_header = 1;
  while ( <F> ) {
    chop;
    s/\r*$//g; # remove annoying CR
    if ( /\s*:\s*/ ) {
      $abbrev = $`;
      $webcaltrans{ $abbrev } = $';
    }
  }
}

( $day, $mon, $year ) = ( localtime( time() ) )[ 3, 4, 5 ];
$header .=
  '# Translation last updated on '
  . sprintf( "%02d-%02d-%04d", $mon + 1, $day, $year + 1900 ) . "\n";

print "\nFinding WebCalendar class, js and php files.\n\n" if ( $verbose );
find \&find_pgm_files, $base_dir;
@files = sort( @files );

#
# Write new translation file.
#
$notfound = 0;
open( OUT, ">$infile" ) || die "Error writing $infile: ";
print OUT $header;
if ( $plugin eq '' ) {
  $foundin{ 'charset' } =
  $foundin{ 'direction' } =
  $foundin{ '__mm__/__dd__/__yyyy__' } =
  $foundin{ '__month__ __dd__' } =
  $foundin{ '__month__ __dd__, __yyyy__' } =
  $foundin{ '__month__ __yyyy__' } =
  $foundin{ 'PROGRAM_NAME' } =
  $foundin{ 'PROGRAM_DATE' } =
  $foundin{ 'PROGRAM_VERSION' } = ' top of this file';

  $text{ 'charset' } =
  $text{ 'direction' } =
  $text{ '__mm__/__dd__/__yyyy__' } =
  $text{ '__month__ __dd__' } =
  $text{ '__month__ __dd__, __yyyy__' } =
  $text{ '__month__ __yyyy__' } =
  $text{ 'PROGRAM_NAME' } =
  $text{ 'PROGRAM_DATE' } =
  $text{ 'PROGRAM_VERSION' } = 1;

  print OUT ( $infile !~ /english-us/i ? '
' . ( '#' x 80 ) . '
#                       DO NOT "TRANSLATE" THIS SECTION                        #
' . ( '#' x 80 ) : '
PROGRAM_NAME: ' . $trans{ 'PROGRAM_NAME' } ) . '
' . ( $infile !~ /english-us/i ? '
# A lone equal sign "=" to the right of the colon, such as "charset: =",
# indicates that the "translation" is identical to the English text.

# Specify a charset (will be sent within meta tag for each page).
' : '' ) . '
charset: ' . $trans{ 'charset' } . ( $infile !~ /english-us/i ? '

# "direction" need only be changed if using a right to left language.
# Options are: ltr (left to right, default) or rtl (right to left).
' : '' ) . '
direction: ' . $trans{ 'direction' } . ( $infile !~ /english-us/i ? '

# In the date formats, change only the format of the terms.
# For example in German.txt the proper "translation" would be
#   __month__ __dd__, __yyyy__: __dd__. __month__ __yyyy__

#  Select elements for date specification.
#  ex)2011-10-13
#     __yyyy__ ... 2011, __mm__ ... 10, __month__ ... October, __dd__ ... 13
' : '' ) . '
__mm__/__dd__/__yyyy__: ' . $trans{ '__mm__/__dd__/__yyyy__' } . '
__month__ __dd__: ' . $trans{ '__month__ __dd__' } . '
__month__ __dd__, __yyyy__: ' . $trans{ '__month__ __dd__, __yyyy__' } . '
__month__ __yyyy__: ' . $trans{ '__month__ __yyyy__' } . '
' . ( $infile !~ /english-us/i ? '
' . ('#' x 80).'
' . ('#' x 80).'
' : '' );
}

foreach $f ( @files ) {
  open( F, $f ) || die "Error reading $f";
  $f =~ s,^\.\.\/,,;
  $pageHeader = "\n" . ( '#' x 40 ) . "\n# Page: $f\n#\n";
  print "Searching $f\n" if ( $verbose );
  %thispage = ();
  while ( <F> ) {
    $data = $_;
    while ( $data =~ /(translate|tooltip)\s*\(\s*['"]/ ) {
      $data = $';
      if ( $data =~ /['"]\s*[,\)]/ ) {
        $text = $`;
        if ( defined( $thispage{ $text } ) || $text eq 'charset' ) {
# already found
        }
        elsif ( defined( $text{ $text } ) ) {
          if ( $show_dups ) {
            print OUT $pageHeader
              . "# \"$text\" previously defined (in $foundin{$text})\n";
            $pageHeader = '';
          }
          $thispage{ $text } = 1;
        }
        else {
          if ( !length( $trans{ $text } ) ) {
            if ( $show_missing ) {
              print OUT $pageHeader;
              $pageHeader = '';
              if ( length( $webcaltrans{ $text } ) ) {
                print OUT "# \"$text\" defined in WebCalendar translation\n";
              }
              else {
                print OUT "#\n# << MISSING >>\n# $text:\n";
                print OUT "# English text: $base_trans{$text}\n#\n"
                  if ( length( $base_trans{ $text } )
                  && $base_trans{ $text } ne $text );
              }
            }
            $notfound++ if ( !length( $webcaltrans{ $text } ) );
          }
          else {
            print OUT $pageHeader;
            $pageHeader = '';
            printf OUT ( "%s: %s\n", $text, $trans{ $text } );
          }
          $foundin{ $text } = $f;
          $text{ $text } = $thispage{ $text } = 1;
        }
        $data = $';
      }
    }
  }
  close( F );
}

print STDERR (
  !$notfound
  ? "All text was found in $infile.  Good job :-)\n"
  : "$notfound translation(s) missing.\n"
);

exit 0;
