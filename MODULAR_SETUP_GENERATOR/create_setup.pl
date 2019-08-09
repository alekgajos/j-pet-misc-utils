#!/usr/bin/env perl

##########################################################################
# Installing dependencies:                                               #
#     cpan install JSON Spreadsheet::Read File::Basename Data::Dumper\   #
#                    File::Map Spreadsheet::ReadSXC                      #
##########################################################################

use warnings;
use strict;
use JSON;
use Getopt::Std;
use Scalar::Util qw(looks_like_number);
use File::Map qw(map_file);
use Data::Dumper;
use Spreadsheet::Read;
use File::Basename;

##########################################################################
# Configuration                                                          #
##########################################################################
# how many rows to skip from the top of the spreadsheet
my $mapping_header_rows = 2;
# number of channels in a single FTAB
my $channels_per_ftab = 105;
# starting channel number (chosen not to overlap with the ild barrel)
my $global_channel_ofset = 2100;
# radius of the 4th layer, measured to the middle strip (7th) of a module
my $layer_4_radius = 38.186;
# theta difference between middle strips of subsequent modules
my $layer_4_theta_diff = 360.0/48.;
# id of the new layer - using 5 for now
# to avoid conflicts with the reference detector stub layer
my $layer_4_id = 5;
# pre-calculated radii of scintillators in a module
my @scin_radii = (38.416, 38.346, 38.289, 38.244, 38.212, 38.192, 38.186,
		  38.192, 38.212, 38.244, 38.289, 38.346, 38.416);

# properties needed for calculation of big barrel scintillator positions
# they are filled using the already-present information
my %layer_radii;
my %slot_thetas;
my %slot_radii;

##########################################################################
# Helper subroutines                                                     #
##########################################################################
my $ftab_mapping;

sub calcGlobalChannel{
    my ($module, $side, $scin, $pmt, $thr) = @_;

    # mirror numbering of scintillators for side b
    $scin = 14 - $scin unless $side==0;

    # make sure the structrure of the spreadsheet is as expected
    my $row = $mapping_header_rows + ($scin-1)*8 + 1;
    my $control_scin_cell = $ftab_mapping->{"A$row"};
    if($scin != $control_scin_cell){
	die "The structure of the FTAB mapping spreadsheet ".
	    "seems different than expected!\n";
    }
    
    $row = $mapping_header_rows + ($scin-1)*8 + ($pmt-1)*2 + $thr;
    my $ftab_channel = $ftab_mapping->{"F$row"};

    if(!looks_like_number($ftab_channel)){
	die "The structure of the FTAB mapping spreadsheet ".
	    "seems different than expected!\n";
    }

    #
    # channels from subsequent FTAB-s are numbered like this:
    #  2100 = Module 1 side A channel 0,
    #  2205 = Module 1 side B channel 0
    #  2310 = Module 2 side A channel 0,
    #  ...
    #  7035 = Module 48 side B channel 0.
    #
    my $no_previous_ftabs = ($module-1)*2 + $side;
    my $global_channel = $global_channel_ofset
	+ $no_previous_ftabs * $channels_per_ftab
	+ $ftab_channel;
    
    return $global_channel;
}

sub calcScinPosition{

    my ($module, $scin_in_module) = @_;

    # calculation scheme copied from j-pet-geant4 code
    my $radius = $scin_radii[$scin_in_module-1];
    $scin_in_module = $scin_in_module - 7;
    my $angle = $layer_4_theta_diff * ($module-1) + 1.04*$scin_in_module;

    use constant PI => 3.14159265358979;
    $angle = $angle * PI / 180.;
    my $x = $radius * cos($angle);
    my $y = $radius * sin($angle);

    return ($x, $y);
}

##########################################################################
# Parse command line options                                             #
##########################################################################
my %options=();
getopts("l:m:i:", \%options);

my $old_setup_filename = "";
my $ftab_mapping_filename = "";
my $run_number = 1;

if( defined $options{l} ){
  $old_setup_filename = $options{l}
}else{
  die "Missing requied parameter: old setup file name (-l).\n";
}

if( defined $options{m} ){
  $ftab_mapping_filename = $options{m};
}else{
  die "Missing requied parameter: FTAB mapping file name (-m).\n";
}

my ($name, $dir, $ext) = fileparse($ftab_mapping_filename, ('.ods'));
if( $ext ne '.ods' ){
  die "The file with ftab mapping must be in the ODS format.\n"
}

##########################################################################
# Read old 3-layer big barrel JSON setup                                 #
##########################################################################
my $old_json_string = "";
map_file $old_json_string, $old_setup_filename;
my $old_setup_map = decode_json $old_json_string;

# handling of run number
#my $setup = (values %$old_setup_map)[0];
# my $run_no = (keys %$old_setup_map)[0];
my $run_no = 100;
if( defined $options{i} and looks_like_number($options{i}) ){
  $run_no = $options{i};
}

## for the new syntax of JSON files
my $setup = $old_setup_map;

##########################################################################
# Extend the entries of the old parametric objects                       #
##########################################################################

# replace frame entry with setup
delete $setup->{"frame"};

$setup->{"setup"} = [
    {
     "id" => 1,
     "description" => "Big Barrel and Modular Detector"
    }
    ];

# Rewrite PMs to a new list
#
# Changes in PM entry structure:
# * pos_in_matrix added and set to 0 to differentiate from SiPM-s (1-4)
# * reference to barrel_slot replaced with reference to scin
my @new_pm_list = ();
foreach(@{$setup->{"pm"}}){

    my %new_pm = (
    	"id" => $_->{"id"},
	"scin_id" => $_->{"barrel_slot_id"},
	"side" => $_->{"side"},
	"pos_in_matrix" => "0",
	"description" => $_->{"id"}
    	);

    push(@new_pm_list, \%new_pm);
}
$setup->{"pm"} = \@new_pm_list;

# Update layers
foreach my $l (@{$setup->{"layer"}}){

    $l->{"setup_id"} = $l->{"frame_id"};
    delete $l->{"frame_id"};

    # by the way, collect the layers radii into a hash
    $layer_radii{$l->{"id"}} = $l->{"radius"};
    
}

# Rewrite barrel_slots to a new list callet slot
#
my @new_slot_list = ();
foreach(@{$setup->{"barrel_slot"}}){

    $slot_thetas{$_->{"id"}} = $_->{"theta"};
    $slot_radii{$_->{"id"}} = $layer_radii{$_->{"layer_id"}};
    
    my %new_slot = (
	"id" => $_->{"id"},
	"layer_id" => $_->{"layer_id"},
	"theta" => $_->{"theta"},
	"type" => "barrel"
	);

    push(@new_slot_list, \%new_slot);
}
$setup->{"slot"} = \@new_slot_list;
delete $setup->{"barrel_slot"};

# Update the scins in the list and rename the list
#
# Changes in scin entry structure:
# * xcenter, ycenter and zcenter added for XY position of strip center
#
foreach my $s (@{$setup->{"scintillator"}}){

    $s->{"slot_id"} = $s->{"barrel_slot_id"};
    delete($s->{"barrel_slot_id"});
  
    use constant PI => 3.14159265358979;
    my $angle = $slot_thetas{$s->{"slot_id"}} * PI / 180.;

    my $x = $slot_radii{$s->{"slot_id"}} * cos($angle);
    my $y = $slot_radii{$s->{"slot_id"}} * sin($angle);

    $s->{"xcenter"} = $x;
    $s->{"ycenter"} = $y;
    $s->{"zcenter"} = 0;
}

$setup->{"scin"} = $setup->{"scintillator"};
delete($setup->{"scintillator"});

##########################################################################
# Read mapping of FTAB channels from and ods spreadsheet                 #
# and create entries corresponding to new parametric objects             #
##########################################################################
$ftab_mapping = ReadData ($ftab_mapping_filename)->[1];

# global IDs of the new objects
my $global_module_id = 200;
my $global_scin_id = 200;
my $global_pmt_id = 400;

# create the new layer
my %layer = (
    "id" => $layer_4_id,
    "name" => "Digital J-PET layer",
    "radius" => $layer_4_radius,
    "setup_id" => 1
    );

# store the new layer object
push(@{$setup->{"layer"}}, \%layer);

# loop over modules
for(my $module=1; $module<=48; $module++){

    $global_module_id++;

    # create module aka slot
    # note: here, module is the new barrel_slot/slot!
    my %slot = (
	"id" => $global_module_id,
	"layer_id" => $layer_4_id,
	"theta" => $layer_4_theta_diff * ($module-1),
	"type" => "module"
	);

    # store the new slot object
    push(@{$setup->{"slot"}}, \%slot);
    
    # loop over scintillators
    for(my $scin=1; $scin<=13; $scin++){

	$global_scin_id++;

	my ($x, $y) = calcScinPosition($module, $scin);
	
	# create scintillator
	my %scin = (
		    "id" => $global_scin_id,
		    "length" => 500,
		    "width" => 6,
		    "height" => 25,
		    "slot_id" => $global_module_id,
		    "xcenter" => $x,
		    "ycenter" => $y,
		    "zcenter" => 0.
		   );
	
	# store the new scintillator object
	push(@{$setup->{"scin"}}, \%scin);

	# loop over sides
	# 0 - A
	# 1 - B
	for(my $side=0; $side<=1; $side++){
  
	    # loop over PMTs
	    for(my $pmt=1; $pmt<=4; $pmt++){
		
		$global_pmt_id++;

		# create PMT
		my %pm = (
		    "id" => $global_pmt_id,
		    "scin_id" => $global_scin_id,
		    "side" => ["A", "B"]->[$side],
		    "pos_in_matrix" => $pmt,
		    "description" => $global_pmt_id
		    );

		# store the new PM object
		push(@{$setup->{"pm"}}, \%pm);

		# loop over thresholds on a single PM
		for(my $thr=1; $thr<=2; $thr++){
        
		    # create channel
		    my $channel_number = calcGlobalChannel($module, $side, $scin, $pmt, $thr);

		    my %channel = (
			"id" => $channel_number,
			"pm_id" => $global_pmt_id,
			"thr_num" => $thr,
			# TODO: handle threshold values once we have them
			"thr_val" => 0.
			);

		    # store the new channel object
		    push(@{$setup->{"channel"}}, \%channel);
		    
		}	
	    }
	}
    }

    # add run number at top level of the JSON file
    my $outer_scope = {
		 "$run_no" => $setup
		};

    my $output_json_text = to_json($outer_scope, { pretty => 1, canonical => 1});
    open(my $fh, '>', 'combined_jpet.json');
    print $fh $output_json_text;
    close $fh;
    
}




