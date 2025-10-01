#!/usr/bin/env perl

use FindBin;
BEGIN {
    unshift @INC, "$FindBin::Bin/../lib";
}

use Mojolicious::Commands;

Mojolicious::Commands->start_app('MyApp');