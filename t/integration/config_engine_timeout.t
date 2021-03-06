#!/usr/bin/env perl

# mt-aws-glacier - Amazon Glacier sync client
# Copyright (C) 2012-2014  Victor Efimov
# http://mt-aws.com (also http://vs-dev.com) vs@vs-dev.com
# License: GPLv3
#
# This file is part of "mt-aws-glacier"
#
#    mt-aws-glacier is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    mt-aws-glacier is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use utf8;
use Test::More tests => 54;
use Test::Deep;
use FindBin;
use lib map { "$FindBin::RealBin/$_" } qw{../lib ../../lib};
use TestUtils 'w_fatal';



my $mtroot = get_temp_dir();
open my $f, ">", "$mtroot/file"; print $f "1"; close $f;

for (
	[qw!create-vault --config glacier.cfg myvault!],
	[qw!delete-vault --config glacier.cfg myvault!],
	[qw!sync --config glacier.cfg --vault myvault --journal j!, '--dir', $mtroot],
	[qw!upload-file --config glacier.cfg --vault myvault --journal j!, '--dir', $mtroot, '--filename', "$mtroot/file"],
	[qw!purge-vault --config glacier.cfg --vault myvault --journal j!],
	[qw!restore --config glacier.cfg --vault myvault --journal j --max-number-of-files 1!, '--dir', $mtroot],
	[qw!restore-completed --config glacier.cfg --vault myvault --journal j!, '--dir', $mtroot],
	[qw!retrieve-inventory --config glacier.cfg --vault myvault!],
	[qw!download-inventory --config glacier.cfg --vault myvault --new-journal j!],
) {
	fake_config sub {
		disable_validations qw/journal secret key/ => sub {
			my $timeout = 60;
			my $res = config_create_and_parse(@$_, qq!--timeout!, $timeout);
			ok !($res->{errors}||$res->{warnings}), "no errors";
			is $res->{options}{timeout}, $timeout, "timeout matches";

			$res = config_create_and_parse(@$_);
			ok !($res->{errors}||$res->{warnings}), "no errors";
			is $res->{options}{timeout}, 180, "timeout is optional but has default value 180";

			$timeout = ('x' x 3);
			$res = config_create_and_parse(@$_, qq!--timeout!, $timeout);
			cmp_deeply $res->{errors}, [{a => 'timeout', format => 'invalid_format', value => $timeout}], "should catch wrong timeout";

			$timeout = 999999999;
			$res = config_create_and_parse(@$_, qq!--timeout!, $timeout);
			cmp_deeply $res->{errors}, [{a => 'timeout', format => 'invalid_format', value => $timeout}], "should catch too large timeout";
		}
	}
}

1;