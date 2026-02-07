#!/usr/bin/perl

# Copyright (c) 2025-2026 David Uhden Collado
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
# This script updates:
#   - feeds/blog.xml and feeds/blog-es.xml (adds a new <item>)
#   - data/articles.json (used by redirect.js to map en/es article filenames)
# -------------------------
# Usage: update-feeds.pl
# Prompts for article info (slug, title, description, pubDate).
#-------------------------
# Outputs to feeds/blog.xml, feeds/blog-es.xml, and data/articles.json
#-------------------------
# Generates RFC2822 pubDate timestamps in GMT.
# Requires Perl with JSON::PP
# Requires UTF-8 support
# Requires POSIX for strftime
# Requires Cwd and File::Basename for path handling
# Requires File::Spec for path handling
# Requires strict and warnings
#-------------------------
# Note: redirect.js reads data/articles.json at runtime.

use strict;
use warnings;
use POSIX qw(strftime);
use File::Spec;
use Getopt::Long;
use JSON::PP;
use Time::Local qw(timegm);

# -------------------------
# Logging
# -------------------------
my $no_color  = 0;
my $is_tty    = ( -t STDOUT )             ? 1 : 0;
my $use_color = ( !$no_color && $is_tty ) ? 1 : 0;

my ( $GREEN, $YELLOW, $RED, $RESET ) = ( "", "", "", "" );
if ($use_color) {
    $GREEN  = "\e[32m";
    $YELLOW = "\e[33m";
    $RED    = "\e[31m";
    $RESET  = "\e[0m";
}

sub logi { print "${GREEN}✅ [INFO]${RESET} $_[0]\n"; }
sub logw { print STDERR "${YELLOW}⚠️ [WARN]${RESET} $_[0]\n"; }
sub loge { print STDERR "${RED}❌ [ERROR]${RESET} $_[0]\n"; }

sub die_tool {
    my ($msg) = @_;
    loge($msg);
    exit 1;
}

my $replace_existing = 0;
GetOptions( 'replace' => \$replace_existing );

my $root_dir =
  File::Spec->catdir( ( File::Spec->splitpath($0) )[1] || '.', '..' );
my $feed_en = File::Spec->catfile( $root_dir, 'feeds', 'blog.xml' );
my $feed_es = File::Spec->catfile( $root_dir, 'feeds', 'blog-es.xml' );

sub prompt {
    my ( $message, $default ) = @_;
    my $suffix = defined $default && length $default ? " [$default]" : '';
    print "$message$suffix: ";
    my $input = <STDIN>;
    defined $input or loge("Could not read input.");
    chomp $input;
    return length $input ? $input : $default;
}

sub read_file {
    my ($path) = @_;
    open my $fh, '<:encoding(UTF-8)', $path
      or loge("Could not open $path for reading: $!");
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub write_file {
    my ( $path, $content ) = @_;
    open my $fh, '>:encoding(UTF-8)', $path
      or loge("Could not open $path for writing: $!");
    print {$fh} $content;
    close $fh;
}

sub xml_escape {
    my ($text) = @_;
    return '' unless defined $text;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    return $text;
}

# Locale-aware RFC2822 formatter (en/es)
sub rfc2822_from_ts_locale {
    my ( $t, $lang ) = @_;
    $lang ||= 'en';
    my @wday_en = qw(Sun Mon Tue Wed Thu Fri Sat);
    my @mon_en  = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @wday_es = qw(dom lun mar mié jue vie sáb);
    my @mon_es  = qw(ene feb mar abr may jun jul ago sep oct nov dic);
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday ) = gmtime($t);
    $year += 1900;

    if ( $lang eq 'es' ) {
        my $wd = $wday_es[$wday] || 'dom';
        my $mn = $mon_es[$mon]   || 'ene';
        return sprintf( '%s, %02d %s %d %02d:%02d:%02d GMT',
            lc($wd), $mday, lc($mn), $year, $hour, $min, $sec );
    }
    else {
        my $wd = $wday_en[$wday] || 'Sun';
        my $mn = $mon_en[$mon]   || 'Jan';
        return sprintf( '%s, %02d %s %d %02d:%02d:%02d GMT',
            $wd, $mday, $mn, $year, $hour, $min, $sec );
    }
}

sub iso_to_epoch {
    my ($s) = @_;
    return undef unless defined $s;
    if ( $s =~
/^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(Z|([+-])(\d{2}):(\d{2}))?$/
      )
    {
        my ( $Y, $M, $D, $h, $m, $sec, $z, $sign, $oh, $om ) =
          ( $1, $2, $3, $4, $5, $6, $7, $8, $9, $10 );
        $Y   -= 0;
        $M   -= 1;
        $D   -= 0;
        $h   -= 0;
        $m   -= 0;
        $sec -= 0;
        my $epoch = timegm( $sec, $m, $h, $D, $M, $Y );

        if ( defined $sign && defined $oh ) {
            my $ofs = $oh * 3600 + $om * 60;
            $epoch -= ( $sign eq '+' ) ? $ofs : -$ofs;
        }
        return $epoch;
    }
    if ( $s =~ /^(\d{4})-(\d{2})-(\d{2})$/ ) {
        my ( $Y, $M, $D ) = ( $1, $2, $3 );
        return timegm( 0, 0, 0, $D, $M - 1, $Y );
    }
    return undef;
}

sub epoch_to_iso {
    my ($t) = @_;
    $t ||= time();
    my ( $sec, $min, $hour, $mday, $mon, $year ) = gmtime($t);
    $year += 1900;
    $mon  += 1;
    return sprintf( '%04d-%02d-%02dT%02d:%02d:%02dZ',
        $year, $mon, $mday, $hour, $min, $sec );
}

sub extract_datetime_from_article {
    my ($path) = @_;
    return undef unless -e $path;
    my $html = read_file($path) || '';
    if ( $html =~ /<time[^>]*\sdatetime\s*=\s*"([^"]+)"/i ) {
        return $1;
    }
    if ( $html =~ /<time[^>]*\sdatetime\s*=\s*'([^']+)'/i ) {
        return $1;
    }
    return undef;
}

sub normalize_slug {
    my ($s) = @_;
    $s //= '';
    $s =~ s/^\s+|\s+$//g;
    $s = lc $s;
    return $s;
}

sub validate_key {
    my ($key) = @_;

   # JSON key used by redirect.js (via articles.json). Allow typical slug chars.
    $key =~ /^[a-z0-9_-]+$/
      or loge("Key '$key' is invalid. Use only [a-z0-9_-].");
}

sub update_feed {
    my (%args)  = @_;
    my $path    = $args{path};
    my $title   = xml_escape( $args{title} );
    my $slug    = $args{slug};
    my $desc    = xml_escape( $args{description} );
    my $lang    = $args{lang}    // 'en';
    my $replace = $args{replace} // 0;

    # Use provided RFC pubdate if passed, otherwise current GMT time
    my $pub = $args{pubdate_rfc} // rfc2822_from_ts_locale( time(), $lang );

    # Keep existing feed link style
    my $link = "./../articles/$slug.html";
    my $guid = $link;

    my $item =
        "\t\t\t\t<item>\n"
      . "\t\t\t\t\t\t<title>$title</title>\n"
      . "\t\t\t\t\t\t<link>$link</link>\n"
      . "\t\t\t\t\t\t<description>$desc</description>\n"
      . "\t\t\t\t\t\t<pubDate>$pub</pubDate>\n"
      . "\t\t\t\t\t\t<guid>$guid</guid>\n"
      . "\t\t\t\t</item>\n\n";

    my $content = read_file($path);

    if ( $content =~ /\Q$link\E/ ) {
        if ( $replace || $replace_existing ) {

            # remove existing <item> blocks that reference this link
            my $before = $content;
            $content =~ s{<item>.*?<link>\Q$link\E.*?</item>\s*}{}gs;
            if ( $content ne $before ) {
                logi("Removed existing item(s) for $link from $path");
            }
        }
        else {
            logw("Feed $path already contains a link to $link. Skipping insert."
            );
            return;
        }
    }

    # Validate pubdate roughly (RFC2822): day, dd Mon yyyy hh:mm:ss GMT
    unless ( defined $pub
        && $pub =~
/^[A-Za-z]{3},\s+\d{1,2}\s+[A-Za-z]{3}\s+\d{4}\s+\d{2}:\d{2}:\d{2}\s+GMT$/
      )
    {
        logw(
"Provided pubDate '$pub' doesn't look like RFC2822; using current date."
        );
        $pub = strftime( '%a, %d %b %Y %H:%M:%S GMT', gmtime() );

        # also update pub variable in item string
        $item =~ s{<pubDate>.*?</pubDate>}{<pubDate>$pub</pubDate>}s;
    }

# Update channel dates (assumes channel-level <pubDate> and <lastBuildDate> exist)
    $content =~ s{<pubDate>[^<]*</pubDate>}{<pubDate>$pub</pubDate>}m;
    $content =~
s{<lastBuildDate>[^<]*</lastBuildDate>}{<lastBuildDate>$pub</lastBuildDate>}m;

    # Insert new item right after </lastBuildDate> when possible
    my $inserted =
      $content =~ s{(<lastBuildDate>[^<]*</lastBuildDate>\s*\n)}{$1\n$item}m;
    if ( !$inserted ) {
        $inserted = $content =~ s{(<channel>\s*\n)}{$1$item}m;
    }
    if ( !$inserted ) {
        $inserted = $content =~ s{(</channel>)}{$item$1}m;
    }

    loge("Could not insert the new item into $path.") unless $inserted;

    write_file( $path, $content );
    logi("Updated feed: $path");
}

sub update_articles_json {
    my (%args)   = @_;
    my $key      = $args{key};
    my $slug_en  = $args{slug_en};
    my $slug_es  = $args{slug_es};
    my $title_en = $args{title_en} // '';
    my $title_es = $args{title_es} // '';
    my $pubdate  = $args{pubdate};

    my $data_dir  = File::Spec->catdir( $root_dir, 'data' );
    my $json_file = File::Spec->catfile( $data_dir, 'articles.json' );

    # Ensure data directory exists
    unless ( -d $data_dir ) {
        mkdir $data_dir or loge("Could not create $data_dir: $!");
    }

    my $articles = {};
    if ( -e $json_file ) {
        my $jcontent = read_file($json_file);
        eval {
            $articles = JSON::PP->new->utf8->decode($jcontent);
            1;
        } or do {
            logw("Could not parse existing $json_file, overwriting.");
            $articles = {};
        };
    }

# redirect.js expects filenames (not paths); it builds URLs relative to /articles/
    $articles->{$key} = {
        en       => "$slug_en.html",
        es       => "$slug_es.html",
        title_en => $title_en,
        title_es => $title_es,
        ( defined $pubdate ? ( pubdate => $pubdate ) : () ),
    };

    # Stable output: canonical sorts keys
    my $json_out = JSON::PP->new->utf8->canonical->pretty->encode($articles);

    # Write as UTF-8 (no need to escape non-ASCII titles)
    open my $fh, '>:encoding(UTF-8)', $json_file
      or loge("Could not open $json_file for writing: $!");
    print {$fh} $json_out;
    close $fh;

    logi("Updated mapping: $json_file");
}

# =========================
# Main
# =========================
my $today = strftime( '%a, %d %b %Y %H:%M:%S GMT', gmtime() );

my $slug_en =
  normalize_slug( prompt( 'English slug (without .html, e.g., gpl)', '' ) );
length $slug_en or loge('English slug is required.');

my $slug_es =
  normalize_slug( prompt( 'Spanish slug (without .html)', $slug_en . '-es' ) );

my $key = normalize_slug(
    prompt( 'Key for data/articles.json (used by redirect.js)', $slug_en ) );
validate_key($key);

my $title_en = prompt( 'Title (English)',       '' );
my $title_es = prompt( 'Title (Spanish)',       '' );
my $desc_en  = prompt( 'Description (English)', '' );
my $desc_es  = prompt( 'Description (Spanish)', '' );

# Try to extract datetime from article header (<time datetime="...">)
my $articles_dir    = File::Spec->catdir( $root_dir, 'articles' );
my $article_en_path = File::Spec->catfile( $articles_dir, $slug_en . '.html' );
my $article_es_path = File::Spec->catfile( $articles_dir, $slug_es . '.html' );
my $found_iso       = extract_datetime_from_article($article_en_path)
  || extract_datetime_from_article($article_es_path);
my $pubdate_input = '';
if ($found_iso) {
    $pubdate_input = $found_iso;
    logi("Found datetime in article header: $found_iso");
}
else {
    $pubdate_input = prompt(
'Publication date ISO (e.g., 2025-03-06T10:00:00Z) or leave blank for now',
        ''
    );
}

# Normalize to epoch (UTC) if possible, otherwise fallback to now
my $pub_epoch = iso_to_epoch($pubdate_input);
unless ( defined $pub_epoch ) {
    if ($pubdate_input) {
        logw(
"Could not parse provided pubdate '$pubdate_input' as ISO; falling back to current time"
        );
    }
    $pub_epoch = time();
}
my $pub_iso    = epoch_to_iso($pub_epoch);
my $pub_rfc_en = rfc2822_from_ts_locale( $pub_epoch, 'en' );
my $pub_rfc_es = rfc2822_from_ts_locale( $pub_epoch, 'es' );

update_feed(
    path        => $feed_en,
    title       => $title_en,
    slug        => $slug_en,
    description => $desc_en,
    lang        => 'en',
    replace     => $replace_existing,
    pubdate_rfc => $pub_rfc_en,
);

update_feed(
    path        => $feed_es,
    title       => $title_es,
    slug        => $slug_es,
    description => $desc_es,
    lang        => 'es',
    replace     => $replace_existing,
    pubdate_rfc => $pub_rfc_es,
);

update_articles_json(
    key      => $key,
    slug_en  => $slug_en,
    slug_es  => $slug_es,
    title_en => $title_en,
    title_es => $title_es,
    pubdate  => $pub_iso,
);

# Run rebuild script to regenerate feeds (ensures consistent ordering and encoding)
my $rebuild_script =
  File::Spec->catfile( $root_dir, 'scripts', 'rebuild-feeds.pl' );
if ( -x $rebuild_script ) {
    logi("Running rebuild script: $rebuild_script");
    my $rc = system( $^X, $rebuild_script );
    if ( $rc != 0 ) {
        logw("Rebuild script exited with code $rc");
    }
}
else {
    logw("Rebuild script not found or not executable: $rebuild_script");
}

logi(
'Done. Review changes in feeds and data/articles.json (redirect.js loads it).'
);
