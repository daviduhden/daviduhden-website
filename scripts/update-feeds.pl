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
# This script updates:
#   - feeds/blog.xml and feeds/blog-es.xml (adds a new <item>)
#   - data/articles.json (used by redirect.js to map en/es article filenames)
#
# Note: redirect.js reads data/articles.json at runtime; this script does NOT
# modify redirect.js anymore.

use strict;
use warnings;
use POSIX qw(strftime);
use FindBin;
use File::Spec;
use JSON::PP;

my $root_dir  = File::Spec->catdir($FindBin::RealBin, '..');
my $feed_en   = File::Spec->catfile($root_dir, 'feeds', 'blog.xml');
my $feed_es   = File::Spec->catfile($root_dir, 'feeds', 'blog-es.xml');

my $GREEN = "\e[32m";
my $YELLOW = "\e[33m";
my $RED = "\e[31m";
my $RESET = "\e[0m";

sub log {
    my ($msg) = @_;
    print "${GREEN}✅ [INFO]${RESET} $msg\n";
}

sub warn {
    my ($msg) = @_;
    print STDERR "${YELLOW}⚠️  [WARN]${RESET} $msg\n";
}

sub error {
    my ($msg, $code) = @_;
    $code //= 1;
    print STDERR "${RED}❌ [ERROR]${RESET} $msg\n";
    exit $code;
}

sub prompt {
    my ($message, $default) = @_;
    my $suffix = defined $default && length $default ? " [$default]" : '';
    print "$message$suffix: ";
    my $input = <STDIN>;
    defined $input or error("Could not read input.");
    chomp $input;
    return length $input ? $input : $default;
}

sub read_file {
    my ($path) = @_;
    open my $fh, '<:raw', $path or error("Could not open $path for reading: $!");
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub write_file {
    my ($path, $content) = @_;
    open my $fh, '>:raw', $path or error("Could not open $path for writing: $!");
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
    $key =~ /^[a-z0-9_-]+$/ or error("Key '$key' is invalid. Use only [a-z0-9_-].");
}

sub update_feed {
    my (%args) = @_;
    my $path   = $args{path};
    my $title  = xml_escape($args{title});
    my $slug   = $args{slug};
    my $desc   = xml_escape($args{description});
    my $pub    = $args{pubdate};

    # Keep existing feed link style
    my $link = "./../articles/$slug.html";
    my $guid = $link;

    my $item = "\t\t\t\t<item>\n"
             . "\t\t\t\t\t\t<title>$title</title>\n"
             . "\t\t\t\t\t\t<link>$link</link>\n"
             . "\t\t\t\t\t\t<description>$desc</description>\n"
             . "\t\t\t\t\t\t<pubDate>$pub</pubDate>\n"
             . "\t\t\t\t\t\t<guid>$guid</guid>\n"
             . "\t\t\t\t</item>\n\n";

    my $content = read_file($path);

    if ($content =~ /\Q$link\E/) {
        warn("Feed $path already contains a link to $link. Skipping insert.");
        return;
    }

    # Update channel dates (assumes channel-level <pubDate> and <lastBuildDate> exist)
    $content =~ s{<pubDate>[^<]*</pubDate>}{<pubDate>$pub</pubDate>}m;
    $content =~ s{<lastBuildDate>[^<]*</lastBuildDate>}{<lastBuildDate>$pub</lastBuildDate>}m;

    # Insert new item right after </lastBuildDate> when possible
    my $inserted = $content =~ s{(<lastBuildDate>[^<]*</lastBuildDate>\s*\n)}{$1\n$item}m;
    if (!$inserted) {
        $inserted = $content =~ s{(<channel>\s*\n)}{$1$item}m;
    }
    if (!$inserted) {
        $inserted = $content =~ s{(</channel>)}{$item$1}m;
    }

    error("Could not insert the new item into $path.") unless $inserted;

    write_file($path, $content);
    log("Updated feed: $path");
}

sub update_articles_json {
    my (%args) = @_;
    my $key      = $args{key};
    my $slug_en  = $args{slug_en};
    my $slug_es  = $args{slug_es};
    my $title_en = $args{title_en} // '';
    my $title_es = $args{title_es} // '';

    my $data_dir  = File::Spec->catdir($root_dir, 'data');
    my $json_file = File::Spec->catfile($data_dir, 'articles.json');

    # Ensure data directory exists
    unless (-d $data_dir) {
        mkdir $data_dir or error("Could not create $data_dir: $!");
    }

    my $articles = {};
    if (-e $json_file) {
        my $jcontent = read_file($json_file);
        eval {
            $articles = JSON::PP->new->utf8->decode($jcontent);
            1;
        } or do {
            warn("Could not parse existing $json_file, overwriting.");
            $articles = {};
        };
    }

    # redirect.js expects filenames (not paths); it builds URLs relative to /articles/
    $articles->{$key} = {
        en       => "$slug_en.html",
        es       => "$slug_es.html",
        title_en => $title_en,
        title_es => $title_es,
    };

    # Stable output: canonical sorts keys
    my $json_out = JSON::PP->new->utf8->canonical->pretty->encode($articles);

    # Write as UTF-8 (no need to escape non-ASCII titles)
        open my $fh, '>:encoding(UTF-8)', $json_file
            or error("Could not open $json_file for writing: $!");
    print {$fh} $json_out;
    close $fh;

        log("Updated mapping: $json_file");
}

# =========================
# Main
# =========================
my $today = strftime('%a, %d %b %Y %H:%M:%S GMT', gmtime());

my $slug_en = normalize_slug(prompt('English slug (without .html, e.g., gpl)', ''));
length $slug_en or error('English slug is required.');

my $slug_es = normalize_slug(prompt('Spanish slug (without .html)', $slug_en . '-es'));

my $key = normalize_slug(prompt('Key for data/articles.json (used by redirect.js)', $slug_en));
validate_key($key);

my $title_en = prompt('Title (English)', '');
my $title_es = prompt('Title (Spanish)', '');
my $desc_en  = prompt('Description (English)', '');
my $desc_es  = prompt('Description (Spanish)', '');
my $pubdate  = prompt('Publication date RFC2822 (e.g., Fri, 07 Mar 2025 10:00:00 GMT)', $today);

update_feed(
    path        => $feed_en,
    title       => $title_en,
    slug        => $slug_en,
    description => $desc_en,
    pubdate     => $pubdate,
);

update_feed(
    path        => $feed_es,
    title       => $title_es,
    slug        => $slug_es,
    description => $desc_es,
    pubdate     => $pubdate,
);

update_articles_json(
    key      => $key,
    slug_en  => $slug_en,
    slug_es  => $slug_es,
    title_en => $title_en,
    title_es => $title_es,
);

log('Done. Review changes in feeds and data/articles.json (redirect.js loads it).');