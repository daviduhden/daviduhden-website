#!/usr/bin/perl
# Content integrity checks for daviduhden-website (bilingual).
# Read-only: verifies the article index, HTML metadata, language
# pairing, blog listing, feeds and sitemap stay consistent.

use strict;
use warnings;

use Carp qw(croak);
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use TestSite       qw(repo_root slurp);
use Encode         qw(decode);
use File::Basename qw(basename);
use File::Spec;
use JSON::PP qw(decode_json);

my $root = repo_root();

sub file {
    my ($relative) = @_;
    return File::Spec->catfile( $root, split m{/}, $relative );
}

sub h1_of {
    my ($path) = @_;
    my $s      = decode( 'UTF-8', slurp($path) );
    my ($h)    = $s =~ m{<h1[^>]*>(.*?)</h1>}s;
    return if !defined $h;
    $h =~ s/<[^>]+>//g;
    $h =~ s/\s+/ /g;
    $h =~ s/^\s+|\s+$//g;
    return $h;
}

my $json = eval { decode_json( slurp( file('data/articles.json') ) ) };
ok( defined $json, 'data/articles.json parses as JSON' )
  or BAIL_OUT("cannot parse article index");

my %covered;
my %lang_of;
my @dupes;
for my $key ( sort keys %{$json} ) {
    my $e = $json->{$key};
    for my $lang (qw(en es)) {
        next if !defined $e->{$lang};
        my $fn = $e->{$lang};
        push @dupes, $fn if $covered{$fn}++;
        $lang_of{$fn} = $lang;
        my $p = file("articles/$fn");
        ok( -f $p, "index entry $key/$lang points to an existing file" );
        next if !-f $p;
        is( h1_of($p), $e->{"title_$lang"}, "title matches <h1> for $fn" );
    }
}
is_deeply( \@dupes, [], 'no article file is listed twice' );

opendir my $dh, file('articles') or croak "opendir articles: $!";
my @html = sort grep { /\.html$/i } readdir $dh;
closedir $dh;
for my $fn (@html) {
    ok( $covered{$fn}, "articles/$fn is listed in data/articles.json" );
}

# --- bilingual pairing / reciprocal hreflang ------------------------
for my $key ( sort keys %{$json} ) {
    my $e = $json->{$key};
    next if !( defined $e->{en} && defined $e->{es} );
    my $en = slurp( file("articles/$e->{en}") );
    my $es = slurp( file("articles/$e->{es}") );
    like(
        $en,
        qr{hreflang="es"[^>]*href=\s*"[^"]*\Q$e->{es}\E"},
        "$e->{en} links to its Spanish version"
    );
    like(
        $es,
        qr{hreflang="en"[^>]*href=\s*"[^"]*\Q$e->{en}\E"},
        "$e->{es} links to its English version"
    );
}

# --- feeds reference existing articles and stay language-separated --
for my $pair ( [ 'blog.xml', 'en' ], [ 'blog-es.xml', 'es' ] ) {
    my ( $name, $want ) = @{$pair};
    my $xml   = slurp( file("feeds/$name") );
    my @links = $xml =~ m{<link>/articles/([^<]+)</link>}g;
    ok( scalar(@links), "$name has items" );
    for my $fn (@links) {
        ok( -f file("articles/$fn"), "$name link targets articles/$fn" );
        is( ( $lang_of{$fn} // '?' ),
            $want, "$name lists only $want articles ($fn)" );
    }
}

# --- sitemap targets exist and covers every article -----------------
my $sm   = slurp( file('sitemap.xml') );
my @locs = $sm =~ m{<loc>(.*?)</loc>}g;
ok( scalar(@locs), 'sitemap has entries' );
for my $loc (@locs) {
    ( my $path = $loc ) =~ s{^https?://[^/]+/?}{};
    $path =~ s{^/}{};
    if ( $path eq '' || $path =~ m{/$} ) {
        ok( -f file( $path . 'index.html' ), "sitemap $loc resolves" );
    }
    else {
        ok( -f file($path), "sitemap $loc resolves" );
    }
}
for my $fn (@html) {
    like( $sm, qr{/articles/\Q$fn\E</loc>}, "articles/$fn appears in sitemap" );
}

# --- pre/code blocks start with code, not whitespace ----------------
{
    my @pages = (
        glob("$root/*.html"),
        glob("$root/articles/*.html"),
        glob("$root/templates/*.html"),
        File::Spec->catfile( $root, 'ddgnoai', 'index.html' ),
    );

    my @bad;
    my $blocks = 0;
    for my $page (@pages) {
        my $html = slurp($page);
        while ( $html =~ m{<pre\b[^>]*>\s*<code\b[^>]*>(.*?)</code>\s*</pre>}gs )
        {
            my $code = $1;
            $blocks++;
            push @bad, $page if $code =~ /^\s/;
        }
    }

    ok( $blocks, 'found pre/code blocks' );
    is_deeply(
        \@bad,
        [],
        'pre/code blocks start with code, not a newline or indentation'
    );
}

# --- blog listing mirrors article dates and feed order --------------
for my $pair (
    [ 'blog.html',    'blog.xml' ],
    [ 'blog-es.html', 'blog-es.xml' ],
  )
{
    my ( $blog, $feed ) = @{$pair};
    my $html = slurp( file($blog) );
    my @entries;
    while (
        $html =~ m{
            <section[^>]*\bid="article-\d+"[^>]*>
            \s*<h2>\s*<a\s+href="[.]/articles/([^"]+[.]html)">.*?</h2>
            \s*<p>\s*<time[^>]*\bdatetime\s*=\s*"([^"]+)">
        }gsx
      )
    {
        push @entries, [ $1, $2 ];
    }

    ok( scalar(@entries), "$blog has article entries" );

    my @feed_links =
      slurp( file("feeds/$feed") ) =~ m{<link>/articles/([^<]+)</link>}g;
    is_deeply(
        [ map { $_->[0] } @entries ],
        \@feed_links,
        "$blog order matches $feed"
    );

    for my $entry (@entries) {
        my ( $filename, $date ) = @{$entry};
        my ($article_date) =
          slurp( file("articles/$filename") )
          =~ /<time[^>]*\bdatetime\s*=\s*"([^"]+)"/i;
        is( $date, $article_date, "$blog date matches articles/$filename" );
    }
}

done_testing();
