#!/usr/bin/perl

# Copyright (c) 2024-2025 David Uhden Collado
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

use strict;
use warnings;
use POSIX qw(strftime);
use FindBin;
use File::Spec;
use JSON::PP;

my $root_dir = File::Spec->catdir($FindBin::RealBin, '..');
my $feed_en   = File::Spec->catfile($root_dir, 'feeds', 'blog.xml');
my $feed_es   = File::Spec->catfile($root_dir, 'feeds', 'blog-es.xml');
my $redirect  = File::Spec->catfile($root_dir, 'redirect.js');

sub prompt {
    my ($message, $default) = @_;
    my $suffix = defined $default && length $default ? " [$default]" : '';
    print "$message$suffix: ";
    my $input = <STDIN>;
    defined $input or die "Could not read input.\n";
    chomp $input;
    return length $input ? $input : $default;
}

sub read_file {
    my ($path) = @_;
    open my $fh, '<', $path or die "Could not open $path for reading: $!\n";
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub write_file {
    my ($path, $content) = @_;
    open my $fh, '>', $path or die "Could not open $path for writing: $!\n";
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

sub update_feed {
    my (%args) = @_;
    my $path   = $args{path};
    my $title  = xml_escape($args{title});
    my $slug   = $args{slug};
    my $desc   = xml_escape($args{description});
    my $pub    = $args{pubdate};

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
        warn "Warning: feed $path already contains a link to $link. Skipping insert.\n";
        return;
    }

    $content =~ s{<pubDate>.*?</pubDate>}{<pubDate>$pub</pubDate>};
    $content =~ s{<lastBuildDate>.*?</lastBuildDate>}{<lastBuildDate>$pub</lastBuildDate>};

    my $inserted = $content =~ s{(<lastBuildDate>.*?</lastBuildDate>\s*\n)}{$1\n$item}ms;
    if (!$inserted) {
        $inserted = $content =~ s{(<channel>\s*\n)}{$1$item}ms;
    }
    if (!$inserted) {
        $inserted = $content =~ s{(</channel>)}{$item$1}ms;
    }

    unless ($inserted) {
        die "Could not insert the new item into $path.\n";
    }

    write_file($path, $content);
    print "Updated feed: $path\n";
}

sub update_redirect {
    my (%args) = @_;
    my $slug_key = $args{slug_key};
    my $slug_en  = $args{slug_en};
    my $slug_es  = $args{slug_es};
    my $title_en = $args{title_en} // '';
    my $title_es = $args{title_es} // '';

    my $data_dir = File::Spec->catdir($root_dir, 'data');
    my $json_file = File::Spec->catfile($data_dir, 'articles.json');

    # ensure data directory exists
    unless (-d $data_dir) {
        mkdir $data_dir or die "Could not create $data_dir: $!\n";
    }

    my $articles = {};
    if (-e $json_file) {
        my $jcontent = read_file($json_file);
        eval {
            $articles = JSON::PP->new->utf8->decode($jcontent);
        };
        if ($@) {
            warn "Warning: could not parse existing $json_file, overwriting.\n";
            $articles = {};
        }
    }

    $articles->{$slug_key} = {
        en => "$slug_en.html",
        es => "$slug_es.html",
        title_en => $title_en,
        title_es => $title_es,
    };

    my $json_out = JSON::PP->new->ascii->pretty->encode($articles);
    write_file($json_file, $json_out);
    print "Updated $json_file\n";
}

my $today = strftime('%a, %d %b %Y %H:%M:%S GMT', gmtime());

my $slug_en = prompt('English slug (without .html, e.g., gpl)', '');
length $slug_en or die "English slug is required.\n";
my $slug_es = prompt('Spanish slug (without .html)', $slug_en . '-es');
my $slug_key = prompt('Key for redirect.js (letters/numbers/underscore only)', $slug_en);
$slug_key =~ /^[a-z0-9_]+$/ or die "Key $slug_key is invalid. Use only [a-z0-9_].\n";

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

update_redirect(
    slug_key => $slug_key,
    slug_en  => $slug_en,
    slug_es  => $slug_es,
);

print "Done. Review changes in feeds and redirect.js.\n";
