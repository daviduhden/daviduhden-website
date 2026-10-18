#!/usr/bin/perl
# Regression tests for scripts/update-feeds.pl (daviduhden-website).

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use TestSite qw(fixture run_input slurp);
use File::Spec;

sub feed {
    my (%a)  = @_;
    my $self = $a{self} // '/feeds/blog.xml';
    my $body = $a{body} // '';
    return <<"XML";
<?xml version="1.0" encoding="UTF-8"?>
<rss xmlns:atom="http://www.w3.org/2005/Atom" version="2.0">
  <channel>
    <title>Blog</title>
    <link>/blog.html</link>
    <description>Desc</description>
    <lastBuildDate>Thu, 01 Jan 2026 00:00:00 GMT</lastBuildDate>
    <atom:link href="$self" rel="self" type="application/rss+xml"/>
$body  </channel>
</rss>
XML
}

sub item {
    my (%a) = @_;
    return
        "    <item>\n"
      . "      <title>$a{title}</title>\n"
      . "      <link>$a{link}</link>\n"
      . "      <description>$a{desc}</description>\n"
      . "      <pubDate>$a{pub}</pubDate>\n"
      . "      <guid isPermaLink=\"false\">$a{link}</guid>\n"
      . "    </item>\n";
}

sub run_update {
    my ( $dir, $input, @args ) = @_;
    my $script = File::Spec->catfile( $dir, 'scripts', 'update-feeds.pl' );
    return run_input( $input, $^X, $script, @args );
}

sub strip_rebuild {
    my ($dir) = @_;
    unlink File::Spec->catfile( $dir, 'scripts', 'rebuild-feeds.pl' );
}

# --- insert English and Spanish items (no rebuild) ------------------
{
    my $dir = fixture(
        'feeds/blog.xml'    => feed(),
        'feeds/blog-es.xml' => feed( self => '/feeds/blog-es.xml' ),
    );
    strip_rebuild($dir);
    my $r = run_update( $dir,
        "newart\nnewart-es\nEN & T\nEN & D\nES T\nES D\n2026-03-04\n" );
    is( $r->{status}, 0, 'insert succeeds' ) or diag( $r->{stderr} );
    my $en = slurp("$dir/feeds/blog.xml");
    my $es = slurp("$dir/feeds/blog-es.xml");
    like( $en, qr{<link>/articles/newart\.html</link>}, 'english item link' );
    like( $en, qr{<title>EN &amp; T</title>}, 'english title escaped' );
    like( $es, qr{<link>/articles/newart-es\.html</link>},
        'spanish item link' );
    like( $es, qr{<title>ES T</title>}, 'spanish title' );
    like( $en, qr{<guid isPermaLink="false">/articles/newart\.html</guid>},
        'guid stable' );
}

# --- non-ASCII input remains valid UTF-8 ----------------------------
{
    my $dir = fixture( 'feeds/blog.xml' => feed() );
    strip_rebuild($dir);
    my $r = run_update( $dir, "unicode\nCaf\xc3\xa9\nDesc\n2026-01-01\n" );
    is( $r->{status}, 0, 'UTF-8 input accepted' ) or diag( $r->{stderr} );
    my $raw = slurp("$dir/feeds/blog.xml");
    like( $raw, qr/Caf\xc3\xa9/, 'input encoded once' );
    unlike( $raw, qr/Caf\xc3\x83\xc2\xa9/, 'input not double encoded' );
}

# --- existing English link warns ------------------------------------
{
    my $existing = item(
        title => 'Dup',
        link  => '/articles/dup.html',
        desc  => 'd',
        pub   => 'Thu, 01 Jan 2026 00:00:00 GMT'
    );
    my $dir = fixture(
        'feeds/blog.xml'    => feed( body => $existing ),
        'articles/dup.html' => "<html lang=\"en\"><body><article>"
          . "<header id=\"article-header\"><h1>Dup</h1>"
          . "<time datetime=\"2026-01-01\">x</time></header>"
          . "</article></body></html>\n",
    );
    strip_rebuild($dir);
    my $before = slurp("$dir/feeds/blog.xml");
    my $r      = run_update( $dir, "dup\nT\nD\n" );
    is( $r->{status}, 0, 'kept without --replace' );
    like( $r->{stderr}, qr/Feed already has/, 'warning emitted' );
    is( slurp("$dir/feeds/blog.xml"), $before, 'feed unchanged' );
}

# --- numeric timezone offsets are applied correctly -----------------
{
    my $dir = fixture(
        'feeds/blog.xml'     => feed(),
        'articles/offs.html' => "<html lang=\"en\"><body><article>"
          . "<header id=\"article-header\"><h1>Offs</h1>"
          . "<time datetime=\"2026-01-01T12:00:00+02:30\">x</time></header>"
          . "</article></body></html>\n",
    );
    strip_rebuild($dir);
    my $r = run_update( $dir, "offs\nT\nD\n" );
    is( $r->{status}, 0, 'run with numeric offset succeeds' )
      or diag( $r->{stderr} );
    like(
        slurp("$dir/feeds/blog.xml"),
        qr{<pubDate>Thu, 01 Jan 2026 09:30:00 GMT</pubDate>},
        'offset minutes are subtracted'
    );
}

# --- invalid slug rejected ------------------------------------------
{
    my $dir = fixture( 'feeds/blog.xml' => feed() );
    strip_rebuild($dir);
    my $r = run_update( $dir, "Bad Slug\n" );
    isnt( $r->{status}, 0, 'invalid slug rejected' );
    like( $r->{stderr}, qr/may only contain lowercase letters/, 'message' );
}

# --- full run with automatic rebuild --------------------------------
{
    my $dir = fixture(
        'feeds/blog.xml'     => feed(),
        'articles/auto.html' => "<html lang=\"en\"><body><article>"
          . "<header id=\"article-header\"><h1>Auto</h1>"
          . "<time datetime=\"2026-03-04\">x</time></header>"
          . "</article></body></html>\n",
    );
    my $r = run_update( $dir, "auto\nAuto\nAuto desc\n" );
    is( $r->{status}, 0, 'run with rebuild succeeds' ) or diag( $r->{stderr} );
    like(
        slurp("$dir/feeds/blog.xml"),
        qr{<link>/articles/auto\.html</link>},
        'item present after rebuild'
    );
}

done_testing();
