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
# Validate and format website files (HTML, XML, SVG, CSS, JS).
# Uses tidy, xmllint, prettier, stylelint, eslint, and vnu.jar.
# Usage:
#   validate-website.pl [--root DIR] [--apply|--check] [--skip-format] [--skip-check] [--no-color] [--verbose]
# See usage() for details.

use strict;
use warnings;

use FindBin;
use File::Spec;
use File::Find;
use Getopt::Long qw(GetOptions);
use File::Temp   qw(tempfile);
use IPC::Open3   qw(open3);
use Symbol       qw(gensym);

# -------------------------
# Options
# -------------------------
my $default_root = File::Spec->catdir( $FindBin::RealBin, '..' );

my $root_dir    = $default_root;
my $mode_apply  = 1;               # default: apply formatting
my $skip_format = 0;
my $skip_check  = 0;
my $no_color    = 0;
my $verbose     = 0;

sub usage {
    print STDERR <<"USAGE";
Usage:
  $0 [--root DIR] [--apply|--check] [--skip-format] [--skip-check] [--no-color] [--verbose]

Modes:
  --apply         Format in place (default)
  --check         Do not modify files; fail if formatting would change

Options:
  --root DIR      Root directory to scan (default: ../ relative to this script)
  --skip-format   Do not run formatters
  --skip-check    Do not run syntax/validator checks
  --no-color      Disable colored output
  --verbose       Print extra info

Env:
  VNU_JAR         Path to vnu.jar (Nu HTML Checker). If unset, uses /usr/share/java/vnu.jar.

Exit codes:
  0  OK
  2  Formatting needed (in --check) and/or validation errors
  1  Tooling/usage error
USAGE
    exit 1;
}

GetOptions(
    "root=s"       => \$root_dir,
    "apply!"       => sub { $mode_apply = 1 },
    "check!"       => sub { $mode_apply = 0 },
    "skip-format!" => \$skip_format,
    "skip-check!"  => \$skip_check,
    "no-color!"    => \$no_color,
    "verbose!"     => \$verbose,
) or usage();

-d $root_dir or die "ERROR: root is not a directory: $root_dir\n";

# -------------------------
# Logging
# -------------------------
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

# -------------------------
# Helpers
# -------------------------
sub have_cmd {
    my ($cmd) = @_;
    return 0 unless defined $cmd && length $cmd;
    for my $dir ( split /:/, ( $ENV{PATH} // "" ) ) {
        my $p = File::Spec->catfile( $dir, $cmd );
        return 1 if -x $p;
    }
    return 0;
}

sub run_cmd {
    my (@cmd) = @_;
    print "[cmd] @cmd\n" if $verbose;
    system(@cmd);
    return 0 if $? == -1;
    return 0 if $? & 127;
    return ( ( $? >> 8 ) == 0 ) ? 1 : 0;
}

sub run_capture {
    my (@cmd) = @_;
    print "[cmd] @cmd\n" if $verbose;

    my $err = gensym;
    my $pid = open3( undef, my $out, $err, @cmd );

    local $/;
    my $stdout = <$out> // "";
    my $stderr = <$err> // "";

    waitpid( $pid, 0 );
    my $rc = ( $? >> 8 );

    return ( $rc, $stdout, $stderr );
}

sub read_all {
    my ($path) = @_;
    open my $fh, '<:raw', $path or return undef;
    local $/;
    my $c = <$fh>;
    close $fh;
    return $c;
}

sub write_all {
    my ( $path, $content ) = @_;
    open my $fh, '>:raw', $path or return 0;
    print {$fh} $content;
    close $fh;
    return 1;
}

sub chunked {
    my ( $aref, $n ) = @_;
    my @out;
    for ( my $i = 0 ; $i < @$aref ; $i += $n ) {
        my $end = $i + $n - 1;
        $end = $#$aref if $end > $#$aref;
        push @out, [ @$aref[ $i .. $end ] ];
    }
    return @out;
}

sub make_tmp_file_in_tmp {
    my ( $suffix, $content ) = @_;
    my ( $fh, $path ) =
      tempfile( "validate-website-XXXXXX$suffix", DIR => "/tmp", UNLINK => 0 );
    print {$fh} $content;
    close $fh;
    return $path;
}

# -------------------------
# Collect files (ONLY: html/htm/xml/svg/css/js/mjs/cjs)
# -------------------------
my ( @html, @xml, @svg, @css, @js );

my %skip_dir = map { $_ => 1 } qw(.git node_modules dist build .cache);

File::Find::find(
    {
        no_chdir => 1,
        wanted   => sub {
            my $path = $File::Find::name;

            if ( -d $path ) {
                my $base = $_;
                if ( $skip_dir{$base} ) {
                    $File::Find::prune = 1;
                }
                return;
            }
            return unless -f $path;

            my $lc = lc($path);
            if ( $lc =~ /\.html?$/ )        { push @html, $path; return; }
            if ( $lc =~ /\.xml$/ )          { push @xml,  $path; return; }
            if ( $lc =~ /\.svg$/ )          { push @svg,  $path; return; }
            if ( $lc =~ /\.css$/ )          { push @css,  $path; return; }
            if ( $lc =~ /\.(js|mjs|cjs)$/ ) { push @js,   $path; return; }
        },
    },
    $root_dir
);

my $total = @html + @xml + @svg + @css + @js;
if ( $total == 0 ) {
    logi("No HTML/XML/SVG/CSS/JS files found under: $root_dir");
    exit 0;
}

logi(   "Found $total files (HTML="
      . scalar(@html)
      . ", XML="
      . scalar(@xml)
      . ", SVG="
      . scalar(@svg)
      . ", CSS="
      . scalar(@css) . ", JS="
      . scalar(@js)
      . ")" );

# -------------------------
# Required tools (NO fallbacks)
# -------------------------
my $tidy      = "tidy";
my $xmllint   = "xmllint";
my $prettier  = "prettier";
my $stylelint = "stylelint";
my $eslint    = "eslint";
my $java      = "java";

sub require_cmd {
    my ( $cmd, $why ) = @_;
    have_cmd($cmd)
      or die_tool("Required tool '$cmd' not found in PATH ($why).");
}

# Only require tools for file types that exist and actions not skipped.
if ( !$skip_format ) {
    require_cmd( $tidy,     "HTML formatting" );
    require_cmd( $xmllint,  "XML/SVG formatting" );
    require_cmd( $prettier, "CSS/JS formatting" );
}
if ( !$skip_check ) {
    require_cmd( $xmllint,   "XML/SVG syntax checks" );
    require_cmd( $stylelint, "CSS checks" );
    require_cmd( $eslint,    "JS checks" );
    require_cmd( $java,      "HTML checks with vnu.jar" );
}

# Nu HTML Checker jar: required for HTML checks if we have HTML and checks are enabled.
my $vnu_jar = $ENV{VNU_JAR} // "/usr/share/java/vnu.jar";
if ( !$skip_check && @html ) {
    -f $vnu_jar
      or die_tool(
"Required vnu.jar not found at '$vnu_jar' (set VNU_JAR or install it to /usr/share/java/vnu.jar)."
      );
}

# xmllint indentation: 2 spaces (closest to tidy indent-spaces 2)
$ENV{XMLLINT_INDENT} = "  ";

# -------------------------
# Temp configs in /tmp (deleted at end)
# -------------------------
my @tmp_paths;

my $prettier_cfg  = "";
my $stylelint_cfg = "";
my ( $eslint_legacy_cfg, $eslint_flat_cfg ) = ( "", "" );

if ( !$skip_format ) {
    $prettier_cfg = make_tmp_file_in_tmp( ".prettierrc.json",
            "{\n"
          . "  \"printWidth\": 80,\n"
          . "  \"tabWidth\": 2,\n"
          . "  \"useTabs\": false\n"
          . "}\n" );
    push @tmp_paths, $prettier_cfg;
    logi("Created temporary prettier config in /tmp: $prettier_cfg")
      if $verbose;
}

if ( !$skip_check ) {
    $stylelint_cfg =
      make_tmp_file_in_tmp( ".stylelint.json", "{\n  \"rules\": {}\n}\n" );
    push @tmp_paths, $stylelint_cfg;
    logi("Created temporary stylelint config in /tmp: $stylelint_cfg")
      if $verbose;

    # ESLint: create both and select based on eslint major version.
    $eslint_legacy_cfg = make_tmp_file_in_tmp( ".eslintrc.json",
            "{\n"
          . "  \"env\": { \"browser\": true, \"es2021\": true },\n"
          . "  \"parserOptions\": { \"ecmaVersion\": \"latest\", \"sourceType\": \"module\" },\n"
          . "  \"rules\": {}\n"
          . "}\n" );
    $eslint_flat_cfg = make_tmp_file_in_tmp( ".eslint.config.cjs",
            "module.exports = [\n" . "  {\n"
          . "    files: [\"**/*.{js,mjs,cjs}\"],\n"
          . "    languageOptions: { ecmaVersion: \"latest\", sourceType: \"module\" },\n"
          . "    rules: {},\n"
          . "  },\n"
          . "];\n" );
    push @tmp_paths, ( $eslint_legacy_cfg, $eslint_flat_cfg );
    logi("Created temporary eslint configs in /tmp.") if $verbose;
}

END {
    unlink $_ for @tmp_paths;
}

# -------------------------
# Tracking
# -------------------------
my %format_needed;
my %check_failed;

sub mark_format_needed {
    $format_needed{ $_[0] } = 1 if defined $_[0] && length $_[0];
}

sub mark_check_failed {
    $check_failed{ $_[0] } = 1 if defined $_[0] && length $_[0];
}

# -------------------------
# Canonical tidy options
# -------------------------
my @tidy_fmt = (
    "-indent", "-quiet",              "-wrap", "80",
    "-utf8",   "--indent-spaces",     "2",     "--tidy-mark",
    "no",      "--preserve-entities", "yes",   "--vertical-space",
    "yes",
);

# -------------------------
# Formatting
# -------------------------
sub tidy_format_or_check_one {
    my ($file) = @_;

    if ($mode_apply) {

        # tidy -m modifies in place.
        # Exit codes: 0 ok, 1 warnings, 2+ errors.
        # Requirement: fail on warnings too => only 0 is acceptable.
        my @cmd = ( $tidy, @tidy_fmt, "-m", $file );
        print "[cmd] @cmd\n" if $verbose;
        system(@cmd);
        my $rc = ( $? >> 8 );

        if ( $rc != 0 ) {
            loge("tidy failed (warnings/errors; exit $rc) for: $file");
            mark_check_failed($file);
        }
        return;
    }

    my ( $rc, $out, $err ) = run_capture( $tidy, @tidy_fmt, $file );

    if ( $rc != 0 ) {
        loge("tidy reported warnings/errors (exit $rc) for: $file");
        mark_check_failed($file);
        return;
    }

    my $before = read_all($file);
    if ( !defined $before || $out ne $before ) {
        mark_format_needed($file);
    }
}

sub xmllint_format_or_check_one {
    my ( $file, $label ) = @_;

    my $before = read_all($file);
    return unless defined $before;

    my ( $rc, $out, $err ) =
      run_capture( $xmllint, "--nonet", "--format", $file );
    if ( $rc != 0 ) {
        loge("$label formatting failed (xmllint) for: $file");
        mark_check_failed($file);
        return;
    }

    if ($mode_apply) {
        if ( $out ne $before ) {
            write_all( $file, $out ) or do {
                loge("Failed to write formatted $label file: $file");
                mark_check_failed($file);
            };
        }
    }
    else {
        if ( $out ne $before ) {
            mark_format_needed($file);
        }
    }
}

sub prettier_format_or_check {
    my ($files_ref) = @_;
    return unless @$files_ref;

    if ($mode_apply) {
        logi("Formatting CSS/JS with prettier...");
        for my $chunk ( chunked( $files_ref, 80 ) ) {
            my $ok = run_cmd(
                $prettier,     "--config", $prettier_cfg, "--write",
                "--log-level", "warn",     @$chunk
            );
            if ( !$ok ) {
                loge(
"prettier failed while formatting (parse error or config error)."
                );
                mark_check_failed($_) for @$chunk;
            }
        }
        return;
    }

    logi("Checking CSS/JS formatting with prettier (no changes)...");
    for my $chunk ( chunked( $files_ref, 80 ) ) {
        my ( $rc, $out, $err ) =
          run_capture( $prettier, "--config", $prettier_cfg,
            "--list-different", "--log-level", "warn", @$chunk );
        if ( $rc == 0 ) {
            next;    # all formatted
        }
        if ( $rc == 1 ) {

            # list-different prints filenames (one per line)
            for my $line ( split /\n/, $out ) {
                $line =~ s/\r$//;
                next unless length $line;
                mark_format_needed($line);
            }
            next;
        }

        # rc 2 (or other): parse error etc.
        loge("prettier failed (parse error or config error).");
        mark_check_failed($_) for @$chunk;
    }
}

# -------------------------
# Checks
# -------------------------
sub check_html_vnu {
    return unless @html;

    logi("Validating HTML with Nu HTML Checker (vnu.jar)...");
    for my $chunk ( chunked( \@html, 40 ) ) {
        my $ok = run_cmd( $java, "-jar", $vnu_jar, "--errors-only", @$chunk );
        if ( !$ok ) {

     # vnu reports per file but parsing is messy; conservatively mark the chunk.
            mark_check_failed($_) for @$chunk;
        }
    }
}

sub check_xml_like {
    my ( $files_ref, $label ) = @_;
    return unless @$files_ref;

    logi("Checking $label well-formedness with xmllint...");
    for my $f (@$files_ref) {
        my $ok = run_cmd( $xmllint, "--noout", "--nonet", $f );
        if ( !$ok ) { mark_check_failed($f); }
    }
}

sub check_css_stylelint {
    return unless @css;

    logi("Checking CSS syntax with stylelint (temp config in /tmp)...");
    for my $chunk ( chunked( \@css, 80 ) ) {
        my $ok = run_cmd( $stylelint, "--config", $stylelint_cfg,
            "--allow-empty-input", @$chunk );
        if ( !$ok ) { mark_check_failed($_) for @$chunk; }
    }
}

sub eslint_major_version {
    my ( $rc, $out, $err ) = run_capture( $eslint, "--version" );
    return 0 if $rc != 0;

    # Typical: "v8.57.0" or "8.57.0"
    if ( $out =~ /v?(\d+)\./ ) { return int($1); }
    return 0;
}

sub check_js_eslint {
    return unless @js;

    my $major = eslint_major_version();
    if ( $major <= 0 ) {
        die_tool(
            "Could not determine eslint version (eslint --version failed).");
    }

    my @base;
    if ( $major >= 9 ) {
        logi(
"Checking JavaScript syntax with eslint (flat config, ESLint v$major)..."
        );
        @base = ( $eslint, "--config", $eslint_flat_cfg );
    }
    else {
        logi(
"Checking JavaScript syntax with eslint (legacy config, ESLint v$major)..."
        );
        @base = ( $eslint, "--no-eslintrc", "--config", $eslint_legacy_cfg );
    }

    for my $chunk ( chunked( \@js, 80 ) ) {
        my $ok = run_cmd( @base, @$chunk );
        if ( !$ok ) { mark_check_failed($_) for @$chunk; }
    }
}

# -------------------------
# Run
# -------------------------
if ( !$skip_format ) {
    if (@html) {
        logi( ( $mode_apply ? "Formatting" : "Checking formatting of" )
            . " HTML using tidy canonical style..." );
        tidy_format_or_check_one($_) for @html;
    }
    if (@xml) {
        logi( ( $mode_apply ? "Formatting" : "Checking formatting of" )
            . " XML (xmllint, 2-space indent)..." );
        xmllint_format_or_check_one( $_, "XML" ) for @xml;
    }
    if (@svg) {
        logi( ( $mode_apply ? "Formatting" : "Checking formatting of" )
            . " SVG (xmllint, 2-space indent)..." );
        xmllint_format_or_check_one( $_, "SVG" ) for @svg;
    }
    if ( @css || @js ) {
        my @pfiles = ( @css, @js );
        prettier_format_or_check( \@pfiles );
    }
}
else {
    logi("Formatting skipped (--skip-format).");
}

if ( !$skip_check ) {
    check_html_vnu()               if @html;
    check_xml_like( \@xml, "XML" ) if @xml;
    check_xml_like( \@svg, "SVG" ) if @svg;
    check_css_stylelint()          if @css;
    check_js_eslint()              if @js;
}
else {
    logi("Checks skipped (--skip-check).");
}

# -------------------------
# Summary / exit
# -------------------------
my @fmt = sort keys %format_needed;
my @bad = sort keys %check_failed;

if ( !$mode_apply && @fmt ) {
    loge(   "Formatting is not clean (--check): "
          . scalar(@fmt)
          . " file(s) would change." );
    for my $i ( 0 .. $#fmt ) {
        last if $i > 199;
        print STDERR "  - $fmt[$i]\n";
    }
}

if (@bad) {
    loge( "Validation/syntax checks failed: " . scalar(@bad) . " file(s)." );
    for my $i ( 0 .. $#bad ) {
        last if $i > 199;
        print STDERR "  - $bad[$i]\n";
    }
}

if ( ( !$mode_apply && @fmt ) || @bad ) {
    exit 2;
}

logi(
    "All website checks passed"
      . (
        $skip_format
        ? ""
        : ( $mode_apply ? " (formatting applied)" : " (formatting clean)" )
      )
      . "."
);
exit 0;
