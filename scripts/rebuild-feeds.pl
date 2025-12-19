#!/usr/bin/perl

# Copyright (c) 2025 David Uhden Collado
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
# This script rebuilds feeds/blog.xml and feeds/blog-es.xml from data/articles.json
# - Reads data/articles.json
# - Ensures articles.json is written with keys sorted alphabetically
# - Extracts first <p> from article files when available
# - Writes feeds with UTF-8 encoding and RFC2822 pubDates
# -------------------------
# Usage: rebuild-feeds.pl
# No arguments
# -------------------------
# Outputs to feeds/blog.xml and feeds/blog-es.xml
# -------------------------
# Requires data/articles.json and articles/*.html to exist
# Requires Perl with JSON::PP
# Requires UTF-8 support
# Requires POSIX for strftime
# Requires Cwd and File::Basename for path handling
# Requires File::Spec for path handling
# Requires strict and warnings
# -------------------------
# Note: This is a simple script and does not handle all edge cases.

use strict;
use warnings;
use JSON::PP;
use File::Spec;
use POSIX          qw(strftime);
use Time::Local    qw(timegm);
use Cwd            qw(abs_path);
use File::Basename qw(dirname);

# Logging
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

sub read_utf8 {
    my ($path) = @_;
    open my $fh, '<:encoding(UTF-8)', $path or return undef;
    local $/;
    my $c = <$fh>;
    close $fh;
    return $c;
}

sub write_utf8 {
    my ( $path, $content ) = @_;
    open my $fh, '>:encoding(UTF-8)', $path
      or die_tool "Could not write $path: $!\n";
    print {$fh} $content;
    close $fh;
}

sub xml_escape {
    my ($s) = @_;
    return '' unless defined $s;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    return $s;
}

sub first_paragraph {
    my ($path) = @_;
    return '' unless -e $path;
    my $html = read_utf8($path) // '';
    if ( $html =~ /<p>(.*?)<\/p>/s ) {
        my $p = $1;
        $p =~ s/<[^>]+>//g;     # strip tags
        $p =~ s/\s+/ /g;
        $p =~ s/^\s+|\s+$//g;
        return $p;
    }
    return '';
}

sub iso_to_epoch {
    my ($s) = @_;
    return undef unless defined $s;

    # Accept formats like 2025-12-16T15:58:53Z or with offset +02:00
    if ( $s =~
/^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(Z|([+-])(\d{2}):(\d{2}))?$/
      )
    {
        my ( $Y, $M, $D, $h, $m, $sec, $z, $sign, $off_h, $off_m ) =
          ( $1, $2, $3, $4, $5, $6, $7, $8, $9, $10 );
        $Y   -= 0;
        $M   -= 1;
        $D   -= 0;
        $h   -= 0;
        $m   -= 0;
        $sec -= 0;
        my $epoch = timegm( $sec, $m, $h, $D, $M, $Y );

        if ( defined $sign && defined $off_h ) {
            my $ofs = $off_h * 3600 + $off_m * 60;
            $epoch -= ( $sign eq '+' ) ? $ofs : -$ofs;
        }
        return $epoch;
    }
    return undef;
}

sub wrap_content_for_tag {
    my ( $content, $cont_indent, $maxlen ) = @_;
    $maxlen      ||= 80;
    $cont_indent ||= 6;
    return $content unless defined $content && length($content) > $maxlen;
    my @words = split( /(\s+)/, $content );
    my @lines;
    my $cur = '';
    for my $w (@words) {
        next if $w eq '';
        if ( length($cur) + length($w) <= $maxlen ) {
            $cur .= $w;
        }
        else {
            push @lines, $cur if $cur ne '';
            $cur = $w;
        }
    }
    push @lines, $cur if $cur ne '';
    return $lines[0] . join(
        '',
        map {
                "\n"
              . ( ' ' x $cont_indent )
              .

              $_
        } @lines[ 1 .. $#lines ]
    ) if @lines > 1;
    return $content;
}

my $script_path  = abs_path($0);
my $root         = File::Spec->catdir( dirname($script_path), '..' );
my $data_file    = File::Spec->catfile( $root, 'data', 'articles.json' );
my $feeds_dir    = File::Spec->catdir( $root, 'feeds' );
my $feed_en      = File::Spec->catfile( $feeds_dir, 'blog.xml' );
my $feed_es      = File::Spec->catfile( $feeds_dir, 'blog-es.xml' );
my $articles_dir = File::Spec->catdir( $root, 'articles' );

my $json_text = read_utf8($data_file) // die_tool "Could not read $data_file\n";
my $articles  = eval { JSON::PP->new->decode($json_text) };
if ( $@ || !$articles ) {
    die_tool "Could not parse $data_file as JSON\n";
}

# Re-write data/articles.json sorted alphabetically by key (stable canonical JSON)
my $sorted = {};
for my $k ( sort keys %$articles ) {
    $sorted->{$k} = $articles->{$k};
}
my $json_out = JSON::PP->new->canonical->pretty->encode($sorted);
write_utf8( $data_file, $json_out );
logi("Wrote sorted $data_file");

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

sub build_items_for_locale {
    my ($locale) = @_;
    my @items_arr;
    for my $key ( sort keys %$sorted ) {
        my $entry = $sorted->{$key};
        next unless exists $entry->{$locale};
        my $slug = $entry->{$locale};
        $slug =~ s/\.html$//;
        my $title_key    = $locale eq 'en' ? 'title_en' : 'title_es';
        my $title        = $entry->{$title_key} // $slug;
        my $article_path = File::Spec->catfile( $articles_dir, "$slug.html" );
        my $desc         = first_paragraph($article_path) || '';

  # prefer explicit pubdate from articles.json (ISO8601), fallback to file mtime
        my $mtime;
        if ( exists $entry->{pubdate} ) {
            $mtime = iso_to_epoch( $entry->{pubdate} );
        }
        $mtime ||=
          ( -e $article_path ) ? ( ( stat($article_path) )[9] ) : time();
        my $pub = rfc2822_from_ts_locale( $mtime, $locale );
        $title = xml_escape($title);
        $desc  = xml_escape($desc);

 # wrap long lines inside tags: description continuation indent = tag indent + 2
        $desc  = wrap_content_for_tag( $desc,  8, 80 );
        $title = wrap_content_for_tag( $title, 6, 80 );
        my $link = "./../articles/$slug.html";
        my $guid = $link;
        my $xml  = "    <item>\n";
        $xml .= "      <title>$title</title>\n";
        $xml .= "      <link>$link</link>\n";
        $xml .= "      <description>$desc</description>\n";
        $xml .= "      <pubDate>$pub</pubDate>\n";
        $xml .= "      <guid>$guid</guid>\n";
        $xml .= "    </item>\n\n";
        push @items_arr, { mtime => $mtime, xml => $xml };
    }

    # sort by mtime descending (newest first)
    @items_arr = sort { $b->{mtime} <=> $a->{mtime} } @items_arr;
    my $items = join( '', map { $_->{xml} } @items_arr );
    return ( $items, scalar @items_arr );
}

sub rebuild_feed {
    my ( $path, $locale ) = @_;
    my $content = read_utf8($path) // '';

    # locate closing tags and prefix area
    my $idx = index( $content, '</channel>' );
    die_tool "Could not parse $path for </channel>" if $idx == -1;
    my $prefix_area = substr( $content, 0, $idx );
    my $tail        = substr( $content, $idx );

    # find lastBuildDate in prefix_area
    my $prefix = '';
    if ( $prefix_area =~ /(.*?<lastBuildDate>.*?<\/lastBuildDate>\s*)/s ) {
        $prefix = $1;
    }
    elsif ( $prefix_area =~ /(.*?<channel>\s*)/s ) {
        $prefix = $1;
    }
    else {
        $prefix = $prefix_area;
    }

    # update channel dates to now (locale-specific)
    my $now = rfc2822_from_ts_locale( time(), $locale );
    $prefix =~ s{<pubDate>[^<]*</pubDate>}{<pubDate>$now</pubDate>}m;
    $prefix =~
s{<lastBuildDate>[^<]*</lastBuildDate>}{<lastBuildDate>$now</lastBuildDate>}m;

    # normalize trailing whitespace so we produce a consistent blank line
    $prefix =~ s/\s+$//s;
    $prefix .= "\n\n";

    my ( $items, $count ) = build_items_for_locale($locale);

    my $new = $prefix . "\n" . $items . $tail;

    # collapse 3+ newlines into exactly two (one blank line)
    $new =~ s/\n{3,}/\n\n/g;
    write_utf8( $path, $new );
    logi("Rebuilt $path with $count items");
}

rebuild_feed( $feed_en, 'en' );
rebuild_feed( $feed_es, 'es' );

exit 0;
