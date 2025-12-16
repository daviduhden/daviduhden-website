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
# Remove metadata from images, audio, video, and PDF files using ExifTool.
# -------------------------
# Usage: strip-metadata.pl [--root DIR] [--apply|--check] [--no-color] [--verbose]
# By default, modifies files in place (--apply).
# Exits with code 2 if any file would change in --check mode.
#-------------------------
# Supports .svg, .ico, .png, .ogg, .ogv, .pdf files.
# Requires the Image::ExifTool Perl library.

use strict;
use warnings;

# Disable ExifTool config file to keep behavior deterministic across machines
BEGIN { $Image::ExifTool::configFile = '' }

use FindBin;
use File::Spec;
use File::Find;
use File::Basename qw(dirname basename);
use File::Temp qw(tempfile);
use Getopt::Long qw(GetOptions);

use Image::ExifTool qw(:Public);

# -------------------------
# Options
# -------------------------
my $default_root = File::Spec->catdir($FindBin::RealBin, '..');

my $root_dir   = $default_root;
my $mode_apply = 1;   # default: apply
my $no_color   = 0;
my $verbose    = 0;

sub usage {
    print STDERR <<"USAGE";
Usage:
  $0 [--root DIR] [--apply|--check] [--no-color] [--verbose]

What it does:
  Removes metadata using the Image::ExifTool Perl library from:
    - Images: .svg, .ico, .png
    - Audio:  .ogg
    - Video:  .ogv
    - Docs:   .pdf

Modes:
  --apply   Modify files in place (default).
  --check   Do not modify files; exit 2 if any file would change.

Exit codes:
  0 OK
  2 Changes required (check) and/or errors/warnings during processing
  1 Usage/tooling error
USAGE
    exit 1;
}

GetOptions(
    "root=s"  => \$root_dir,
    "apply!"  => sub { $mode_apply = 1 },
    "check!"  => sub { $mode_apply = 0 },
    "no-color!" => \$no_color,
    "verbose!"  => \$verbose,
) or usage();

-d $root_dir or die "ERROR: root is not a directory: $root_dir\n";

# -------------------------
# Logging (English)
# -------------------------
my $is_tty = (-t STDOUT) ? 1 : 0;
my $use_color = (!$no_color && $is_tty) ? 1 : 0;

my ($GREEN, $YELLOW, $RED, $RESET) = ("", "", "", "");
if ($use_color) {
    $GREEN  = "\e[32m";
    $YELLOW = "\e[33m";
    $RED    = "\e[31m";
    $RESET  = "\e[0m";
}

sub logi { print "${GREEN}✅ [INFO]${RESET} $_[0]\n"; }
sub logw { print STDERR "${YELLOW}⚠️  [WARN]${RESET} $_[0]\n"; }
sub loge { print STDERR "${RED}❌ [ERROR]${RESET} $_[0]\n"; }

# -------------------------
# File collection
# -------------------------
my %skip_dir = map { $_ => 1 } qw(.git node_modules dist build .cache);

sub ext_lc {
    my ($p) = @_;
    return "" unless defined $p;
    return ($p =~ /\.([^.\/]+)$/) ? lc($1) : "";
}

my (@targets, @ref_targets);

File::Find::find(
    {
        no_chdir => 1,
        wanted   => sub {
            my $path = $File::Find::name;

            if (-d $path) {
                my $base = $_;
                if ($skip_dir{$base}) {
                    $File::Find::prune = 1;
                }
                return;
            }
            return unless -f $path;

            my $e = ext_lc($path);
            return if $e eq "";

            return unless $e =~ /^(svg|ico|png|ogg|ogv|pdf)$/;

            push @targets, $path;
        },
    },
    $root_dir
);

@targets = sort @targets;

if (!@targets) {
    logi("No target files found under: $root_dir");
    exit 0;
}

logi("Found " . scalar(@targets) . " target file(s) under: $root_dir");

# -------------------------
# Metadata stripping (ExifTool)
# -------------------------
my $et = Image::ExifTool->new;

# Track results
my %need_changes;   # file => 1
my %changed;        # file => 1
my %errors;         # file => 1

sub mark_need    { $need_changes{$_[0]} = 1 if defined $_[0] && length $_[0]; }
sub mark_changed { $changed{$_[0]} = 1 if defined $_[0] && length $_[0]; }
sub mark_error   { $errors{$_[0]} = 1 if defined $_[0] && length $_[0]; }

sub make_tmp_path_nonexistent {
    my ($dir, $base, $ext) = @_;
    my ($fh, $tmp) = tempfile(".stripmeta-$base-XXXXXX.$ext", DIR => $dir, UNLINK => 0);
    close $fh;
    unlink $tmp; # ExifTool refuses to overwrite an existing destination file
    return $tmp;
}

sub strip_one_file_check {
    my ($path) = @_;
    my $rel = File::Spec->abs2rel($path, $root_dir);

    my $dir = dirname($path);
    my $base = basename($path);
    $base =~ s/[^A-Za-z0-9_.-]+/_/g;
    my $ext = ext_lc($path);

    $et->SetNewValue();   # reset queued edits
    $et->SetNewValue('*'); # delete all metadata :contentReference[oaicite:1]{index=1}

    my $tmp = make_tmp_path_nonexistent($dir, $base, $ext);

    my $r = $et->WriteInfo($path, $tmp); # 1=written, 2=written no changes, 0=error :contentReference[oaicite:2]{index=2}
    my $err = $et->GetValue('Error');
    my $wrn = $et->GetValue('Warning');

    unlink $tmp if -e $tmp;

    if (defined $err && length $err) {
        loge("ExifTool error for $rel: $err");
        mark_error($rel);
        return 0;
    }
    if (defined $wrn && length $wrn) {
        # Strict: warnings are treated as failures (metadata removal may be incomplete)
        loge("ExifTool warning for $rel: $wrn");
        mark_error($rel);
        return 0;
    }

    if ($r == 1) {
        mark_need($rel);
        return 0;
    }
    if ($r == 2) {
        return 1;
    }

    # r==0 without Error text is still failure
    loge("ExifTool failed for $rel (WriteInfo returned 0).");
    mark_error($rel);
    return 0;
}

sub strip_one_file_apply {
    my ($path) = @_;
    my $rel = File::Spec->abs2rel($path, $root_dir);

    $et->SetNewValue();    # reset queued edits
    $et->SetNewValue('*'); # delete all metadata :contentReference[oaicite:3]{index=3}

    my $r = $et->WriteInfo($path); # overwrite original :contentReference[oaicite:4]{index=4}
    my $err = $et->GetValue('Error');
    my $wrn = $et->GetValue('Warning');

    if (defined $err && length $err) {
        loge("ExifTool error for $rel: $err");
        mark_error($rel);
        return 0;
    }
    if (defined $wrn && length $wrn) {
        # Strict: treat warnings as failures
        loge("ExifTool warning for $rel: $wrn");
        mark_error($rel);
        return 0;
    }

    if ($r == 1) {
        mark_changed($rel);
        return 1;
    }
    if ($r == 2) {
        return 1; # already clean
    }

    loge("ExifTool failed for $rel (WriteInfo returned 0).");
    mark_error($rel);
    return 0;
}

# -------------------------
# Main
# -------------------------
if (!$mode_apply) {
    logi("Running in --check mode (no files will be modified).");
    for my $p (@targets) {
        strip_one_file_check($p);
    }

    my @need = sort keys %need_changes;
    my @bad  = sort keys %errors;

    if (@need) {
        loge("Metadata stripping required (--check): " . scalar(@need) . " file(s) would change.");
        for my $i (0..$#need) { last if $i > 200; print STDERR "  - $need[$i]\n"; }
    }
    if (@bad) {
        loge("Errors/warnings encountered: " . scalar(@bad) . " item(s).");
        for my $i (0..$#bad) { last if $i > 200; print STDERR "  - $bad[$i]\n"; }
    }

    exit((@need || @bad) ? 2 : 0);
}

logi("Running in --apply mode (files will be modified in place).");
for my $p (@targets) {
    my $rel = File::Spec->abs2rel($p, $root_dir);
    logi("Stripping metadata: $rel") if $verbose;
    strip_one_file_apply($p);
}

my @bad = sort keys %errors;
if (@bad) {
    loge("Completed with errors/warnings: " . scalar(@bad) . " item(s).");
    for my $i (0..$#bad) { last if $i > 200; print STDERR "  - $bad[$i]\n"; }
    exit 2;
}

my $n_changed = scalar(keys %changed);
logi("Done. Files changed: $n_changed");
exit 0;
