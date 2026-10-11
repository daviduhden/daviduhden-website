#!/usr/bin/perl
# Regression tests for scripts/rebuild-feeds.pl (daviduhden-website).
# All work happens in isolated temporary fixtures.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use TestSite qw(fixture slurp);
use File::Spec;

sub article {
    my (%a) = @_;
    my $lang  = $a{lang}  // 'en';
    my $time  = $a{time}  // '2026-01-02';
    my $title = $a{title} // 'Title';
    my $desc  = $a{desc}  // 'Description';
    return "<!DOCTYPE html>\n<html lang=\"$lang\">\n<head>\n"
      . "<meta charset=\"utf-8\">\n"
      . "<meta name=\"description\" content=\"$desc\">\n"
      . "</head>\n<body>\n<article>\n"
      . "<header id=\"article-header\">\n<h1>$title</h1>\n"
      . "<p class=\"meta\"><time datetime=\"$time\">x</time></p>\n"
      . "</header>\n</article>\n</body>\n</html>\n";
}

sub feed {
    my (%a) = @_;
    my $self  = $a{self}  // '/feeds/blog.xml';
    my $title = $a{title} // 'Test Blog';
    return <<"XML";
<?xml version="1.0" encoding="UTF-8"?>
<rss xmlns:atom="http://www.w3.org/2005/Atom" version="2.0">
  <channel>
    <title>$title</title>
    <link>/blog.html</link>
    <description>Channel description</description>
    <lastBuildDate>Thu, 01 Jan 2026 00:00:00 GMT</lastBuildDate>
    <atom:link href="$self" rel="self" type="application/rss+xml"/>
  </channel>
</rss>
XML
}

sub run_rebuild {
    my ( $dir, @args ) = @_;
    my $script = File::Spec->catfile( $dir, 'scripts', 'rebuild-feeds.pl' );
    my $r      = TestSite::run( $^X, $script, @args );
    return ( $r, $dir );
}

sub item_slugs {
    my ($xml) = @_;
    my @s = $xml =~ m{<link>/articles/([^<]+)\.html</link>}g;
    return @s;
}

# --- deterministic ordering -----------------------------------------
{
    my $dir = fixture(
        'feeds/blog.xml'  => feed(),
        'articles/b.html' => article( time => '2026-01-01' ),
        'articles/a.html' => article( time => '2026-01-01' ),
        'articles/c.html' => article( time => '2026-02-01' ),
    );
    my ( $r, $d ) = run_rebuild($dir);
    is( $r->{status}, 0, 'rebuild succeeds' )
      or diag( $r->{stdout} . $r->{stderr} );
    my @slugs = item_slugs( slurp("$d/feeds/blog.xml") );
    is_deeply( \@slugs, [ 'c', 'a', 'b' ], 'date desc, slug asc' );
}

# --- reproducibility across run, TZ and locale ----------------------
{
    my $dir = fixture(
        'feeds/blog.xml'  => feed(),
        'articles/a.html' => article( time => '2026-01-01' ),
        'articles/b.html' => article( time => '2026-01-01' ),
    );
    my $script = File::Spec->catfile( $dir, 'scripts', 'rebuild-feeds.pl' );
    my $file   = "$dir/feeds/blog.xml";
    TestSite::run( $^X, $script );
    my $first = slurp($file);
    TestSite::run( $^X, $script );
    is( slurp($file), $first, 'repeated run identical' );
    local $ENV{TZ}     = 'Asia/Tokyo';
    local $ENV{LC_ALL} = 'C';
    TestSite::run( $^X, $script );
    is( slurp($file), $first, 'TZ/locale independent' );
}

# --- escaping / entities --------------------------------------------
{
    my $dir = fixture(
        'feeds/blog.xml' => feed(),
        'articles/x.html' => article(
            title => 'A & B',
            desc  => 'd &amp; d &lt;e&gt;'
        ),
    );
    my ( $r, $d ) = run_rebuild($dir);
    is( $r->{status}, 0, 'rebuild succeeds' );
    my $xml = slurp("$d/feeds/blog.xml");
    like( $xml, qr{<title>A &amp; B</title>}, 'escaped once' );
    unlike( $xml, qr{&amp;amp;}, 'no double encoding' );
    like( $xml, qr{<description>d &amp; d &lt;e&gt;</description>},
        'entities decoded then re-escaped' );
}

# --- channel entity preservation ------------------------------------
{
    my $dir = fixture(
        'feeds/blog.xml'  => feed( title => 'A &amp; B' ),
        'articles/a.html' => article(),
    );
    my ( $r, $d ) = run_rebuild($dir);
    my $xml = slurp("$d/feeds/blog.xml");
    like( $xml, qr{<title>A &amp; B</title>}, 'channel entity kept' );
    unlike( $xml, qr{&amp;amp;}, 'no double encoding' );
}

# --- English and Spanish feeds are separated ------------------------
{
    my $dir = fixture(
        'feeds/blog.xml'    => feed(),
        'feeds/blog-es.xml' => feed( self => '/feeds/blog-es.xml' ),
        'articles/en.html'  => article( lang => 'en', title => 'EN' ),
        'articles/es.html'  => article( lang => 'es', title => 'ES' ),
    );
    my ( $r, $d ) = run_rebuild($dir);
    is( $r->{status}, 0, 'rebuild succeeds' );
    my @en = item_slugs( slurp("$d/feeds/blog.xml") );
    my @es = item_slugs( slurp("$d/feeds/blog-es.xml") );
    is_deeply( \@en, ['en'], 'english feed has only english article' );
    is_deeply( \@es, ['es'], 'spanish feed has only spanish article' );
}

# --- index.html ignored, atomic mode, no temp files -----------------
{
    my $dir = fixture(
        'feeds/blog.xml'      => feed(),
        'articles/index.html' => article( title => 'Index' ),
        'articles/a.html'     => article( title => 'A' ),
    );
    my $file = "$dir/feeds/blog.xml";
    chmod 0640, $file;
    my ( $r, $d ) = run_rebuild($dir);
    is( $r->{status}, 0, 'rebuild succeeds' );
    is_deeply( [ item_slugs( slurp($file) ) ], ['a'], 'index.html skipped' );
    is( ( stat $file )[2] & 07777, 0640, 'mode preserved' );
    opendir my $dh, "$dir/feeds" or die $!;
    my @tmp = grep { /^\.tmp-/ } readdir $dh;
    closedir $dh;
    is_deeply( \@tmp, [], 'no temp files left' );
}

# --- empty articles directory ---------------------------------------
{
    my $dir = fixture( 'feeds/blog.xml' => feed() );
    my ( $r, $d ) = run_rebuild($dir);
    is( $r->{status}, 0, 'rebuild succeeds with no articles' );
    unlike( slurp("$d/feeds/blog.xml"), qr/<item>/, 'no items' );
}

# --- UTF-8 ----------------------------------------------------------
{
    my $dir = fixture(
        'feeds/blog.xml' => feed(),
        'articles/u.html' => article( title => "Caf\x{e9} \x{263A}" ),
    );
    my ( $r, $d ) = run_rebuild($dir);
    is( $r->{status}, 0, 'rebuild succeeds with UTF-8' );
    my $raw = slurp("$d/feeds/blog.xml");
    like( $raw, qr/Caf\xc3\xa9/, 'é encoded as UTF-8' );
    like( $raw, qr/\xe2\x98\xba/, '☺ encoded as UTF-8' );
}

# --- missing feed is an error ---------------------------------------
{
    my $dir = fixture( 'articles/a.html' => article() );
    my $script = File::Spec->catfile( $dir, 'scripts', 'rebuild-feeds.pl' );
    my $r = TestSite::run( $^X, $script );
    isnt( $r->{status}, 0, 'missing feed fails' );
    like( $r->{stderr}, qr/No supported feed files found/, 'clear error' );
}

# --- optional absolute base URL; GUIDs stay stable ------------------
{
    my $dir = fixture(
        'feeds/blog.xml'  => feed(),
        'articles/a.html' => article(),
    );
    my ( $r, $d ) = run_rebuild( $dir, '--base-url', 'https://example.org' );
    is( $r->{status}, 0, 'base-url run succeeds' );
    my $xml = slurp("$d/feeds/blog.xml");
    like( $xml, qr{<link>https://example\.org/articles/a\.html</link>},
        'item link made absolute' );
    like( $xml, qr{<link>https://example\.org/blog\.html</link>},
        'channel link made absolute' );
    like( $xml, qr{<atom:link href="https://example\.org/feeds/blog\.xml"},
        'atom self link made absolute' );
    like( $xml, qr{<guid isPermaLink="false">/articles/a\.html</guid>},
        'guid stays root-relative and stable' );
}

done_testing();
