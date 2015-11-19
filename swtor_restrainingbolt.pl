#
#	Star Wars: The Old Republic
#	Restraining Bolt
#
#=============================================================================

use strict;
use warnings;

use Env;
use Switch;
use Digest::MD5;
use File::Copy;
use Getopt::Long;
use File::Spec;
use Win32::TieRegistry;

use constant{
	PROGRAM_VERSION => "201511181736",
	PROGRAM_SHORT_NAME => "restrainingbolt",
	PROGRAM_NAME => "Restraining Bolt",
	PROGRAM_DESCRIPTION => "Ship Droid Mod",
	GAME_NAME => "Star Wars: The Old Republic",

	#	Special
		
	INVALID_HASH => "***",
	NO_DATA_ALPHA => "",
	NO_DATA_NUMERIC => -1,

	#	Defaults

	DEFAULT_OPT_NO_DATA_FILE => 0,
	DEFAULT_OPT_USE_JUMPBACK => 0,
	DEFAULT_OPT_NO_BACKUP => 0,			# Not Implemented
	DEFAULT_DEBUG => 0,				# 0 Debug Off, 1 DEBUG, 2 DEBUG TRACE
	DEFAULT_NO_WRITE => 0,				# 0 Normal, 1 Don't actually patch
	DEFAULT_GAME_ROOT => ".",
	DEFAULT_BACKUP_ROOT => ".",
	DEFAULT_DATA_ROOT => ".",
	FOLDER_BACKUP => "Backup",
	FOLDER_DATA => "SWTOR_MOD",
	DEBUG => 1,
	TRACE => 2,
	MOD_FILE_COUNT => 2,
	DATA_FILE => "swtor_restrainingbolt.dat",

	#	SWTOR

	SWTOR_ASSET_MAGIC_LEN => 3,
	SWTOR_ASSET_MAGIC => "MYP",
	SWTOR_ASSETS_FOLDER => "Assets",
	SWTOR_NAME_REPUBLIC => "Republic",
	SWTOR_NAME_IMPERIAL => "Imperial",
	SWTOR_ASSET_VERSION_FILENAME => "assets_swtor_main_version.txt",
	SWTOR_ASSET_FILE_REPUBLIC => "swtor_en-us_cnv_comp_chars_rep_1",
	SWTOR_ASSET_FILE_IMPERIAL => "swtor_en-us_cnv_comp_chars_imp_1",
	SWTOR_ASSET_SOURCE_REPUBLIC => "c2n2",
	SWTOR_ASSET_SOURCE_IMPERIAL => "2vr8",
	SWTOR_FILE_EXTENSION => "tor",
	SWTOR_X64_REGISTRY_KEY => "HKEY_LOCAL_MACHINE\\SOFTWARE\\Wow6432Node\\BioWare\\Star Wars-The Old Republic",
	SWTOR_X86_REGISTRY_KEY => "HKEY_LOCAL_MACHINE\\SOFTWARE\\BioWare\\Star Wars-The Old Republic",
	SWTOR_REGISTRY_VALUE => "Install Dir",
	REPLACE_REPUBLIC => "XXXX",
	REPLACE_IMPERIAL => "XXXX",

	#	Data Buffering

	READ_BUFFER_SIZE => 0,			#	Use File Length
#	READ_BUFFER_SIZE => 262144,		#	256KB
#	READ_BUFFER_SIZE => 1048576,		#	1MB
#	READ_BUFFER_SIZE => 67108864,		#	64MB
#	READ_BUFFER_SIZE => 268435456,		#	256MB
#	READ_BUFFER_SIZE => 536870912,		#	512MB

};


# Variables, Arrays and Structures

my $debug;

my $use_jumpback = DEFAULT_OPT_USE_JUMPBACK;
my $no_datafile = DEFAULT_OPT_NO_DATA_FILE;
my $no_backup = DEFAULT_OPT_NO_BACKUP;				#	Not Implemented

my $backuproot;
my $gameroot;
my $dataroot;
my $detected_gameroot;

my $folder_assets;
my $folder_data;
my $folder_backup;

my $assetpathname;
my $backuppathname;
my $active_path;

my $asset_version_patch;
my $asset_version_data;
my $hash_asset_republic;
my $hash_asset_imperial;

my $datafile_version = PROGRAM_VERSION;

my $stored_version_patch;
my $stored_version_data;
my $stored_hash_asset_republic;
my $stored_hash_asset_imperial;
my $stored_is_patched;
my $stored_gameroot;
my $stored_backuproot;

my $retval;
my $retcode;

my $buffer;
my $reason;

my $pathname_republic_asset;
my $pathname_imperial_asset;
my $pathname_republic_backup;
my $pathname_imperial_backup;
my $pathname_datafile;
my $pathname_asset_version;

my $search_republic;
my $search_imperial;

my $replace_republic;
my $replace_imperial;

my $game_name;

my $file_asset_version;
my $file_republic_assets;
my $file_imperial_assets;
my $file_data;

my $name_republic;
my $name_imperial;

my $ext_assets;

my $start_run_time;
my $finish_run_time;
my $elapsed_run_time;
my $registry_key;
my $registry_value;

my $temp_gameroot = "";
my $temp_backuproot= "";
my $temp_dataroot = "";

my $temp_path;

my $flag_using_default_gameroot = 1;
my $flag_using_default_backuproot = 1;
my $flag_using_default_dataroot = 1;
my $flag_failed_parsing_asset_version = 0;
my $flag_skip_restore = 0;
my $flag_skip_asset_version_check = 0;
my $flag_skip_patch = 0;
my $flag_skip_backup = 0;
my $flag_assets_verified = 0;
my $flag_update_datafile = 0;
my $flag_asset_checksum_match = 0;
my $flag_game_path_detected = 0;
my $flag_updated_assets = 0;
my $flag_data_file_read = 0;
my $flag_new_data_file = 0;
my $flag_assets_already_patched = 0;
my $flag_success = 0;
my $flag_backup_ok = 1;
my $flag_backup_success = 0;
my $flag_debug_no_op = DEFAULT_NO_WRITE;
my $flag_restore_operation = 0;
my $flag_exit = 0;
my $flag_trace = -1;

my $flag_assets_exist = 0;
my $flag_backups_exist = 0;

my $local_temp = $ENV{TEMP};
my $local_appdata = $ENV{LOCALAPPDATA};

my $mod_file_count = MOD_FILE_COUNT;

$gameroot = DEFAULT_GAME_ROOT;
$backuproot = DEFAULT_BACKUP_ROOT;
$dataroot = DEFAULT_DATA_ROOT;
$detected_gameroot = "";

$folder_backup  = FOLDER_BACKUP;
$folder_data = FOLDER_DATA;
$folder_assets = SWTOR_ASSETS_FOLDER;

$file_republic_assets = SWTOR_ASSET_FILE_REPUBLIC;
$file_imperial_assets = SWTOR_ASSET_FILE_IMPERIAL;
$file_asset_version = SWTOR_ASSET_VERSION_FILENAME;
$file_data = DATA_FILE;

$search_republic = SWTOR_ASSET_SOURCE_REPUBLIC;
$search_imperial = SWTOR_ASSET_SOURCE_IMPERIAL;

$replace_republic = REPLACE_REPUBLIC;
$replace_imperial = REPLACE_IMPERIAL;

$ext_assets = SWTOR_FILE_EXTENSION;

$name_republic = SWTOR_NAME_REPUBLIC;
$name_imperial = SWTOR_NAME_IMPERIAL;

$game_name = GAME_NAME;

$debug = DEFAULT_DEBUG;

$assetpathname = NO_DATA_ALPHA;
$backuppathname = NO_DATA_ALPHA;

$stored_version_patch = NO_DATA_NUMERIC;
$stored_version_data = NO_DATA_NUMERIC;
$stored_hash_asset_republic = INVALID_HASH;
$stored_hash_asset_imperial = INVALID_HASH;
$stored_is_patched = NO_DATA_NUMERIC;
$stored_gameroot = NO_DATA_ALPHA;
$stored_backuproot = NO_DATA_ALPHA;

$retval = 0;
$retcode = 0;


#-----------------------------------------------------------
# Program Start
#-----------------------------------------------------------

$start_run_time = time;

$active_path = File::Spec->curdir();

writelog(PROGRAM_NAME . " v" . PROGRAM_VERSION);
writelog(GAME_NAME . " (" . PROGRAM_DESCRIPTION . ")");
writelog();

writelog("DEBUG MODE ENABLED",DEBUG);
writelog("TRACE MODE ENABLED",TRACE);

if (READ_BUFFER_SIZE > 0) {
	writelog("Data Buffer Size: " . READ_BUFFER_SIZE,DEBUG);
	if ($use_jumpback) {
		writelog("Using JumpBack Scanning.");
	}
}

if ($flag_debug_no_op) {
	writelog("NO ACTUAL PATCHES WILL OCCUR",DEBUG);
}

#	Locate SWTOR Install (command line can override)

writelog("Attempting to locate game installation",TRACE);
$registry_value = $Registry->{SWTOR_X64_REGISTRY_KEY . "\\" . SWTOR_REGISTRY_VALUE} or $registry_key = "";
if ($registry_value) {
	$detected_gameroot = $registry_value;
} else {
	$registry_value = $Registry->{SWTOR_X86_REGISTRY_KEY . "\\" . SWTOR_REGISTRY_VALUE} or $registry_key = "";
	if ($registry_value) {
		$detected_gameroot = $registry_value;
	}
}
if ($registry_value) {
	writelog("Installation located at '$detected_gameroot'",TRACE);
	$flag_game_path_detected = 1;
} else {
	writelog("Could not locate game installation",TRACE);
	$flag_game_path_detected = 0;
}

#	Check Local Temp for use as Backup Root

writelog("Configuring Default Data and Backup Locations",TRACE);
if ($local_temp) {
	if (-d $local_temp) {
		writelog("Attempting to use '$local_temp' for backups",TRACE);
		$backuproot = File::Spec->catfile($local_temp, $folder_data);
		if (-d $backuproot) {
			writelog("'$backuproot' exists",TRACE);
		} else {
			writelog("Creating '$backuproot'",TRACE);
			if (mkdir $backuproot) {
				writelog("Created '$backuproot' OK",TRACE);
			} else {
				$backuproot = DEFAULT_BACKUP_ROOT;
				writelog("Backup root fallback to '$backuproot'",TRACE);			}
		}
	}
} else {
	$backuproot = DEFAULT_BACKUP_ROOT;
	writelog("Backup root fallback to '$backuproot'",TRACE);
}

if ($local_appdata) {
	if (-d $local_appdata) {
		$dataroot = $local_appdata;
		writelog("Using '$dataroot' for data storage",TRACE);
	} else {
		$dataroot = DEFAULT_DATA_ROOT;
		writelog("Data root fallback to '$dataroot'",TRACE);
	}
} else {
	$dataroot = DEFAULT_DATA_ROOT;
	writelog("Data root fallback to '$dataroot'",TRACE);
}

#	Temporary Store Roots


$temp_gameroot = $gameroot;
$temp_backuproot = $backuproot;
$temp_dataroot = $dataroot;

#	Process Options

my $result = GetOptions (
			"data=s" => \$dataroot,				# Specify Mod Data Folder
			"backup=s" => \$backuproot,			# Specify Backup Folder
			"game=s" => \$gameroot,				# Specify Game Folder
			"version|ver" => sub{showVersion()},		# Show Version
			"help|?" => sub{showHelp()},			# Show Help
			"restore|r" => \$flag_restore_operation,	# Restore From Backup
			"nodata" => \$no_datafile,			# Don't Use Data File
			"nobackup" => \$no_backup,			# Don't Use Backups (Restore Not Available)
			"debug" => \$debug,				# Debug Messages
			"trace" => \$flag_trace,			# Debug Messages - Trace Level
			"debug_nopatch" => \$flag_debug_no_op,		# Debug: Don't Actually Patch
);


if ($flag_trace > 0) {
	$debug = TRACE;
}

if ($no_backup > 0) {
	writelog("WARNING!!!"),
	writelog("You have specified the NO BACKUP option."),
	writelog();
	writelog("This will disable the -restore function entirely.");
	writelog();
	writelog("If you wish to restore your asset files you will need to:");
	writelog("* Copy them from your own backup");
	writelog("* Perform a repair in the $game_name launcher");
	writelog();
}


if ($temp_dataroot ne $dataroot) {
	$flag_using_default_dataroot = 0;
}

if ($temp_gameroot ne $gameroot) {
	$flag_using_default_gameroot = 0;
}
	
if ($temp_backuproot ne $backuproot) {
	$flag_using_default_backuproot = 0;
}



if ($no_datafile > 0) {
	writelog("Data file is disabled,");
} else {
	#	Data File Build Path

	writelog("Building Data File Path",TRACE);

	if ($flag_using_default_dataroot) {
		writelog("Using Default Data File Path",TRACE);
	} else {
		writelog("Using Specified Data File Path",TRACE);
	}

	$pathname_datafile = File::Spec->catfile($dataroot, $folder_data);
	$pathname_datafile = File::Spec->catfile($pathname_datafile, $file_data);

	#	Read Data File

	if (-e $pathname_datafile) {
		writelog("Attempting to read data file at '$pathname_datafile'",DEBUG);
		if (readDataFile($pathname_datafile)) {
			$flag_data_file_read = 1;

			if ($flag_using_default_gameroot) {
				if ($stored_gameroot ne DEFAULT_GAME_ROOT) {
					writelog("Checking stored game root",DEBUG);
					if (length($stored_gameroot) > 0) {
						if (-d $stored_gameroot) {
							$gameroot = $stored_gameroot;
							$flag_using_default_gameroot = 0;
							writelog("Using stored game location",TRACE);
						} else {
							writelog("Stored game location, '$stored_gameroot' does not exist",TRACE);
						}
					}
				}
			}

			if ($flag_using_default_backuproot) {
				if ($stored_backuproot ne DEFAULT_BACKUP_ROOT) {
					writelog("Checking stored backup root",DEBUG);
					if (length($stored_backuproot) > 0) {
						if (-d $stored_backuproot) {
							$backuproot = $stored_backuproot;
							$flag_using_default_backuproot = 0;
							writelog("Using stored backup location",TRACE);
						} else {
							writelog("Stored backup location, '$stored_backuproot' does not exist",TRACE);
						}
					}
				}	
			}
		} else {
			writelog("ERROR: Failed to read data file. Creating new one.",DEBUG);
			$flag_data_file_read = 0;
			$flag_new_data_file = 1;
		}
	} else {
		writelog("ERROR: No data file. Creating new one.",DEBUG);
		$flag_data_file_read = 0;
		$flag_new_data_file = 1;
	}
}


#	Use Detected Game Root if not set

if ($flag_using_default_gameroot) {
	if ($flag_game_path_detected) {
		$gameroot = $detected_gameroot;
		$flag_using_default_gameroot = 0;
		writelog("Using detected game location location.");
	}
}

#	Warn If Game Root and Backup Root are defaults

if ($flag_using_default_gameroot) {
	writelog("WARNING: Game location not detected or specified, using current folder.");
} 

if ($flag_using_default_backuproot) {
	writelog("WARNING: Backup location not specified, using current folder.");
} 

#	Build Asset and Backup Paths

writelog("Building Asset and Backup Paths",TRACE);

$pathname_republic_asset = File::Spec->catfile($gameroot, $folder_assets);
$pathname_republic_asset = File::Spec->catfile($pathname_republic_asset, "$file_republic_assets.$ext_assets");

$pathname_republic_backup = File::Spec->catfile($backuproot, $folder_backup);
$pathname_republic_backup = File::Spec->catfile($pathname_republic_backup, "$file_republic_assets.$ext_assets");

$pathname_imperial_asset = File::Spec->catfile($gameroot, $folder_assets);
$pathname_imperial_asset = File::Spec->catfile($pathname_imperial_asset, "$file_imperial_assets.$ext_assets");

$pathname_imperial_backup = File::Spec->catfile($backuproot, $folder_backup);
$pathname_imperial_backup = File::Spec->catfile($pathname_imperial_backup, "$file_imperial_assets.$ext_assets");

$pathname_asset_version = File::Spec->catfile($gameroot, $folder_assets);
$pathname_asset_version = File::Spec->catfile($pathname_asset_version, $file_asset_version);

#	Status (Debug)

writelog("'$active_path' is the current folder.",DEBUG);
writelog("Using '$gameroot' as the location for $game_name.",DEBUG);
writelog("Using '$backuproot\\$folder_backup' for the backup folder.",DEBUG);
writelog("Using '$pathname_asset_version' for the asset version.",DEBUG);

if ($flag_new_data_file) {
	writelog("Using '$pathname_datafile' for the new data file.",DEBUG);
} else {
	writelog("Using '$pathname_datafile' for the data file.",DEBUG);
}

#	Get Asset Version

if (-e $pathname_asset_version) {
	$retval = getAssetVersion($pathname_asset_version);
	($asset_version_patch,$asset_version_data) = split(/\|/,$retval,2);

	if ($asset_version_patch eq NO_DATA_NUMERIC) {
		$flag_failed_parsing_asset_version = 1;
	}

	if ($asset_version_data eq NO_DATA_NUMERIC) {
		$flag_failed_parsing_asset_version = 1;
	}

	if ($flag_failed_parsing_asset_version) {
		writelog("ERROR: Failed to parse asset version file.");
	} else {
		writelog("Asset Version is Patch: $asset_version_patch; Data: $asset_version_data",TRACE);
	}
} else {
	writelog("ERROR: Could not locate asset version file.");
}

if ($no_datafile > 0) {
	# 	No Data File
} else {
	if ($flag_data_file_read) {
		writelog("Using Data File: '$pathname_datafile'.",DEBUG);
	} else {
		writelog("Creating New Data File: '$pathname_datafile'.",DEBUG);
		if (-d $dataroot) {
			writelog("Folder '$dataroot' Exists",DEBUG);
			$temp_path = File::Spec->catfile($dataroot, $folder_data);
			if (-d $temp_path) {
				writelog("Folder '$temp_path' Exists",DEBUG);
			} else {
				writelog("Folder '$temp_path' Does Not Exist",DEBUG);
				if (mkdir $temp_path) {
					writelog("Created '$temp_path' OK",DEBUG);
				} else {
					writelog("Attempt to Create '$temp_path' FAILED",DEBUG);
				}
			}
		} else {
			writelog("ERROR: Data folder does not exist!");
		}
	}
}

#	Check if backups exist

if (-e $pathname_republic_backup) {
	$flag_backups_exist++;
}

if (-e $pathname_imperial_backup) {
	$flag_backups_exist++;
}

#	Run Restore Operation (if selected)

if ($flag_restore_operation) {
	optRestoreOperation();
}

#	Verify Assets

writelog("Verifying $game_name Assets");

writelog("$name_republic Asset Pathname: $pathname_republic_asset",DEBUG);
writelog("$name_republic Backup Pathname: $pathname_republic_backup",DEBUG);
writelog("$name_imperial Asset Pathname: $pathname_imperial_asset",DEBUG);
writelog("$name_imperial Backup Pathname: $pathname_imperial_backup",DEBUG);

if (-e $pathname_republic_asset) {
	if (verifyAssetFile($pathname_republic_asset)) {
		$flag_assets_exist++ 
	} else {
		writelog("ERROR: $name_republic asset file is invalid.");
		$flag_exit = 1;
	}
} else {
	writelog("ERROR: Could not find $name_republic asset file.");
	$flag_exit = 1;
}

if (-e $pathname_imperial_asset) {
	if (verifyAssetFile($pathname_imperial_asset)) {
		$flag_assets_exist++ 
	} else {
		writelog("ERROR: $name_imperial asset file is invalid.");
		$flag_exit = 1;
	}
} else {
	writelog("ERROR: Could not find $name_imperial asset file.");
	$flag_exit = 1;
}

if ($flag_assets_exist == $mod_file_count) {
	$flag_assets_already_patched = assetsPatched();
} else {
	writelog("Could not locate one or more asset files.");
	writelog("Modification Cancelled");
	$flag_exit = 1;
}

if ($flag_assets_already_patched == $mod_file_count) {
	$flag_exit = 1;
}

if (!$flag_exit) {
	if (!$flag_skip_asset_version_check) {
		if (($stored_version_patch != $asset_version_patch) || ($stored_version_data ne $asset_version_data)) {
			$flag_updated_assets = 1;

			if ($flag_new_data_file == 1) {
				writelog("New Data.",DEBUG);
			writelog("Current Asset Version is Patch: $asset_version_patch; Data: $asset_version_data",DEBUG);
			} else {
				writelog("Updating Data.",DEBUG);			
				writelog(" Stored Asset Version is Patch: $stored_version_patch; Data: $stored_version_data",DEBUG);
				writelog("Current Asset Version is Patch: $asset_version_patch; Data: $asset_version_data",DEBUG);
			}

			$hash_asset_republic = INVALID_HASH;
			$hash_asset_imperial = INVALID_HASH;

			if (getAssetHashes()) {
				writelog("$name_republic Asset Hash: $hash_asset_republic",DEBUG);
				writelog("$name_imperial Asset Hash: $hash_asset_imperial",DEBUG);

				$stored_version_patch = $asset_version_patch;
				$stored_version_data = $asset_version_data;
				$stored_hash_asset_republic = $hash_asset_republic;
				$stored_hash_asset_imperial = $hash_asset_imperial;

				if ($flag_assets_already_patched == $mod_file_count) {
					$stored_is_patched = 1;
				} else {
					$stored_is_patched = 0;
				}
		
				if ($no_datafile > 0) {
					#	No Data File
				} else {
					$retval = writeDataFile($pathname_datafile);
	
					if ($retval) {
						writelog("Data File Written OK",DEBUG);
						$flag_update_datafile = 0;
					} else {
						writelog("ERROR: Could not write data file.");
					}
				}
			} else {
				writelog("ERROR: Could not get updated checksums!");
			}

		} else {
			# Data Version is the same

			writelog("Data Unchanged",DEBUG);
			writelog("Asset Version is Patch: $asset_version_patch; Data: $asset_version_data",DEBUG);

			$flag_updated_assets = 0;
		}
	}
}

# 	Determine if backups are present

if (!$flag_exit) {
	if ($flag_backups_exist == $mod_file_count) {
		if ($flag_updated_assets) {
			writelog("Backups Will Be Refreshed.");
			$flag_skip_backup = 0;
		} else {
			writelog("Backups Already Exist, Skipping.");
			$flag_skip_backup = 1;
		}
	} else {
		$flag_skip_backup = -1;
	}
}

#	Determine if backups are stale

if (!$flag_exit) {
	if (!$flag_skip_backup) {
		if ($flag_assets_already_patched) {
			writelog("Assets Are Already Patched!");
			$flag_skip_backup = 3;
			if ($flag_backups_exist == $mod_file_count) {
				$retval = 0;
				$retval = isPatched($pathname_republic_backup,$replace_republic);
				if ($retval > 0) {
					$retval++;
				}
				$retval = isPatched($pathname_imperial_backup,$replace_imperial);
				if ($retval > 0) {
					$retval++;
				}	

				if ($retval > 0) {
					writelog("Backups are not clean!  Restore will not be available.");
					$flag_skip_backup = 6;
				}
			}

			
		}
	}
}

writelog(" Asset Status: $flag_assets_exist",DEBUG);
writelog("Backup Status: $flag_backups_exist",DEBUG);
writelog("Flags:",DEBUG);
writelog("   	          Exit: $flag_exit",DEBUG);
writelog("           Skip Backup: $flag_skip_backup",DEBUG);
writelog("        Data File Read: $flag_data_file_read ($flag_new_data_file)",DEBUG);
writelog("        Assets Updated: $flag_updated_assets",DEBUG);
writelog("Assets Already Patched: $flag_assets_already_patched",DEBUG);


#	Back Up Asset Files (if needed)

if (!$flag_exit) {
	if ($flag_skip_backup > 0) {
		$flag_backup_ok = 255;

		if ($flag_skip_backup == 3) {
			$flag_backup_ok = -1;
		}

		if ($flag_skip_backup == 6) {
			$flag_backup_ok = -2;
		}
	} else {

		#	Check Backup Location

		writelog("Checking backup root: '$backuproot'",DEBUG);
		if (-d $backuproot ) {
			$temp_path = File::Spec->catfile($backuproot, $folder_backup);
			writelog("Checking folder: '$temp_path'",DEBUG);
			if (-d $temp_path) {
				writelog("Backup folder exists",DEBUG);
			} else {
				writelog("Creating backup folder",DEBUG);
				if (mkdir $temp_path) {
					writelog("Created backup folder OK",DEBUG);
				} else {
					writelog("Created backup folder FAILED",DEBUG);
				}
					
			}
		} else {
			writelog("ERROR: '$backuproot' does not exist.");
		}

		writelog("Backing Up Assets.");
		writelog("Backing Up Asset File: $name_republic");
		$retval = backupFile($pathname_republic_asset,$pathname_republic_backup);
		if ($retval > 0) {
			$flag_backup_success++;
		} else {
			$flag_backup_ok = 0;
		}
	
		writelog("Backup: $retval = $pathname_republic_asset to $pathname_republic_backup",DEBUG);

		writelog("Backing Up Asset File: $name_imperial");
		$retval = backupFile($pathname_imperial_asset,$pathname_imperial_backup);
		if ($retval > 0) {
			$flag_backup_success++;
		} else {
			$flag_backup_ok = 0;
		}

		writelog("Backup: $retval = $pathname_imperial_asset to $pathname_imperial_backup",DEBUG);

		if ($flag_backup_success == $mod_file_count) {
			writelog("Backups Successful",DEBUG);
			$flag_backup_ok = 1;
		} else {
			writelog("Backups Failed",DEBUG);
			$flag_backup_ok = 0;
		}
	}
} 


#	Patch Assets

if (!$flag_exit) {
	if ($flag_backup_ok > 0) {
		if (!$flag_skip_patch) {
			$flag_success = 0;

			writelog("Patching Assets.");

			writelog("Patching Assets: $name_republic");
			$retval = patchFile($pathname_republic_asset,$search_republic,$replace_republic);
			if ($retval > 0) {
				$flag_success++;
			}

			writelog("Patching Assets: $name_imperial");
			$retval = patchFile($pathname_imperial_asset,$search_imperial,$replace_imperial);
			if ($retval > 0) {
				$flag_success++;
			}
		
			if ($flag_success == $mod_file_count) {
				$stored_is_patched = 1;

				if ($no_datafile > 0) {
					#	No Data File
				} else {
					$retval = writeDataFile($pathname_datafile);

					if ($retval) {
						writelog("Data File Written OK",DEBUG);
						$flag_update_datafile = 0;
					} else {
						writelog("ERROR: Could not write data file.");
					}
				}
			}
		}
	}
} else {
	if (!$flag_exit) {
		writelog("Error Backing Up Assets, Modification Cancelled.");	
		$flag_success = 0;
	}
}

#	Revise Data File if Required

if (!$flag_exit) {
	if ($flag_update_datafile) {
		writelog("Updating data file from $datafile_version to " . PROGRAM_VERSION,TRACE);	
		$stored_backuproot = $backuproot;
		if (writeDataFile($pathname_datafile)) {
			writelog("Data File Updated OK",DEBUG);
		} else {
			writelog("ERROR: Could not update data file.");
		}
	}
}


#	Report Status

if ($flag_success == $mod_file_count) {
	if ($flag_assets_already_patched ==  $mod_file_count) {
		writelog("Modification Already In Place!");
	} else {
		writelog("Modification Successful!");
	}
	writelog();
	writelog("To restore original assets:");
	showTips();
	writelog();
} else {
	if (!$flag_exit) {
		writelog("Modification Failed");
		writelog();
		writelog("Before attempting to run this again,");
		writelog("you may need to restore original assets:");
		showTips();
		writelog();
	}
}

$finish_run_time = time;
$elapsed_run_time = $finish_run_time - $start_run_time;

writelog("Execution time was $elapsed_run_time seconds(s)");
writelog("Program Completed");

#-----------------------------------------------------------
# FUNCTIONS
#-----------------------------------------------------------

#-----------------------------------------------------------
# Write Log
#-----------------------------------------------------------
sub writelog{
	my $temp_string = shift;
	my $debug_message = shift;
	my $flag_show_message = 1;
	my $prefix_message = "";

	$debug_message = 0 unless defined $debug_message;
	$temp_string = "" unless defined $temp_string;

	if ($debug_message) {
		$flag_show_message = 0;

		if ($debug > 0) {
			if (($debug >= DEBUG) && ($debug_message == DEBUG)) {
				$prefix_message = "DEBUG";
				$flag_show_message = 1;
			}

			if (($debug >= TRACE) && ($debug_message == TRACE)) {
				$prefix_message = "TRACE";
				$flag_show_message = 1;
			}
		}
	}

	
	if ($flag_show_message) {
		if ($prefix_message) {
			$temp_string = "[$prefix_message] $temp_string";
		}
		print "$temp_string\n";
	}

	return;
}

#-----------------------------------------------------------
# Verify SWTOR Asset File
#-----------------------------------------------------------
sub verifyAssetFile{
	my $pathname = shift;
	my $retval = 0;
	my $flag_magic_ok = 0;
		
	return $retval unless defined $pathname;

	writelog("verifyAssetFile '$pathname'",TRACE);

 	if (open(my $fh, '<', $pathname)) {
		binmode($fh);
		writelog("'$pathname' is open in binary mode as READ ONLY",TRACE);
		read($fh, $buffer, 48);
		writelog("'$pathname' is closed",TRACE);	
		close($fh);
		if (substr($buffer,0,SWTOR_ASSET_MAGIC_LEN) eq SWTOR_ASSET_MAGIC) {
			$flag_magic_ok = 1;
		}
	} else {
		writelog("Could not open '$pathname'",TRACE);	
	}
	
	if ($flag_magic_ok) {
		$retval = 1;
	}

	return $retval;
}
	
#-----------------------------------------------------------
# Are Assets Already Patched?
#-----------------------------------------------------------
sub assetsPatched{
	my $tempval;
	my $retval = 0;

	writelog("assetsPatched()",TRACE);

	$tempval = 0;

	$tempval = isPatched($pathname_republic_asset,$replace_republic);
	if ($tempval > 0) {
		$retval++;
	}

	$tempval = isPatched($pathname_imperial_asset,$replace_imperial);
	if ($tempval > 0) {
		$retval++;
	}

	return $retval;
}

#-----------------------------------------------------------
# Check if Asset Already Patched
#-----------------------------------------------------------
sub isPatched{
	my $pathname = shift;
	my $searchfor = shift;

	my $flag_eof = 0;
	my $flag_loop = 1;
	my $flag_search = 1;

	my $retval = -1;

	my $index = 0;
	my $index_position;

	my $file_pointer;
	my $file_pointer_offset;

	my $string_location;
	my $match_counter = 0;
	my $read_counter = 0;
	my $jump_back = 0;
	my $read_buffer_size = 0;

	$read_buffer_size = READ_BUFFER_SIZE;

	return $retval unless defined $pathname;
	return $retval unless defined $searchfor;

	writelog("isPatched '$pathname'",TRACE);

	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($pathname);

	$size = 0 unless defined $size;

	if ($size == 0) {
		return $retval;
	}

	if ($read_buffer_size == 0) {
		$read_buffer_size = $size;
		$use_jumpback = 0;
	}

	if ($read_buffer_size > $size) {
		$read_buffer_size = $size;
		$use_jumpback = 0;
	}

	writelog("Searching '$pathname' for '$searchfor'",DEBUG);
	writelog("Asset file is $size bytes",DEBUG);

	if ($use_jumpback) {
		writelog("Using Jumpback Feature",DEBUG);
	}
	if ($read_buffer_size == $size) {
		writelog("Not buffering data",DEBUG);
	} else {
		writelog("Buffering data $read_buffer_size bytes",DEBUG);
	}

 	if (open(my $fh, '<', $pathname)) {
		binmode($fh);
		writelog("'$pathname' is open in binary mode as READ ONLY",TRACE);

		$retval = 0;

		while( $flag_loop) {
			$read_counter++;
			read($fh, $buffer, $read_buffer_size);
			$file_pointer = tell($fh);
			$file_pointer_offset = $file_pointer - $read_buffer_size;
			if ($file_pointer_offset < 1) {
				$file_pointer_offset = 0;
			}
			$flag_search = 1;
			$index_position = 0;
			writelog("Frame $read_counter, read " . length($buffer) . " bytes",TRACE);
			while ($flag_search) {
				$index = index($buffer,$searchfor,$index_position);
				if ($index >= 0) {
					$string_location = $file_pointer_offset + $index;
					$index_position = $index + 1;
					$match_counter++;
				} else {
					$flag_search = 0;
				}
			}

			# EOF Checks

			if (length($buffer) <= $read_buffer_size) {
				writelog("Buffer is smaller or equal to read buffer size",TRACE);	
				if (eof($fh)) {
					$flag_eof = 1;
				}
				if (length($buffer) == $read_buffer_size) {
					$flag_eof = 1;
				}
				if ($flag_eof) {
					$flag_loop = 0;
				}
			} else {
				if ($use_jumpback) {
					$jump_back = length($searchfor) * 2;
					if ($file_pointer - $jump_back > 0) {
						writelog("Jumping back $jump_back bytes",TRACE);		
						$file_pointer = $file_pointer - $jump_back;
					}
				}
			}
		}
		writelog("'$pathname' is closed",TRACE);	
		close($fh);
	} else {
		writelog("ERROR: Could not open the asset file.");
	}

	if ($match_counter > 0) {
		$retval = 1;
	}

	if ($retval > 0) {
		writelog("Found $match_counter matches of '$searchfor'",TRACE);
	} else {
		if ($retval == 0) {
			writelog(" Read Frames: $read_counter",TRACE);
			writelog("     Matches: $match_counter",TRACE);
		}
	}

	return $retval;
}

#-----------------------------------------------------------
# Patch File
#-----------------------------------------------------------
sub patchFile{
	my $pathname = shift;
	my $searchfor = shift;
	my $replace = shift;

	my $flag_eof = 0;
	my $flag_loop = 1;
	my $flag_search = 1;

	my $retval = -1;

	my $index = 0;
	my $index_position;

	my $file_pointer;
	my $file_pointer_offset;

	my $string_location;
	my $match_counter = 0;
	my $read_counter = 0;
	my $replace_counter = 0;
	my $string_buffer = "";
	my $jump_back = 0;
	my $read_buffer_size = 0;

	$read_buffer_size = READ_BUFFER_SIZE;

	return $retval unless defined $pathname;
	return $retval unless defined $searchfor;
	return $retval unless defined $replace;

	writelog("patchFile '$pathname'",TRACE);

	if ((length($searchfor)) != (length($replace))) {
		writelog("ERROR: Search string and replace string are not the same length!");
		writelog("'$searchfor' is " . length($searchfor) . " bytes",DEBUG);
		writelog("'$replace' is " . length($replace) . " bytes",DEBUG);
		return $retval;
	}

	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($pathname);

	$size = 0 unless defined $size;

	if ($size == 0) {
		return $retval;
	}

	if ($read_buffer_size == 0) {
		$read_buffer_size = $size;
		$use_jumpback = 0;
	}

	if ($read_buffer_size > $size) {
		$read_buffer_size = $size;
		$use_jumpback = 0;
	}

	writelog("Searching '$pathname' to replace '$searchfor' with '$replace'",DEBUG);
	writelog("Asset file is $size bytes",DEBUG);

	if ($use_jumpback) {
		writelog("Using Jumpback Feature",DEBUG);
	}
	if ($read_buffer_size == $size) {
		writelog("Not buffering data",DEBUG);
	} else {
		writelog("Buffering data $read_buffer_size bytes",DEBUG);
	}

 	if (open(my $fh, '+<', $pathname)) {
		binmode($fh);
		writelog("'$pathname' is open in binary mode as READ/WRITE",TRACE);
		$retval = 0;

		while( $flag_loop) {
			$read_counter++;
			read($fh, $buffer, $read_buffer_size);
			$file_pointer = tell($fh);
			$file_pointer_offset = $file_pointer - $read_buffer_size;
			if ($file_pointer_offset < 1) {
				$file_pointer_offset = 0;
			}
			$flag_search = 1;
			$index_position = 0;
			writelog("Frame $read_counter, read " . length($buffer) . " bytes",DEBUG);
			while ($flag_search) {
				$index = index($buffer,$searchfor,$index_position);
				if ($index >= 0) {
					$string_location = $file_pointer_offset + $index;
					$index_position = $index + 1;
					$match_counter++;
					writelog("Found '$searchfor' at $index near $file_pointer ($string_location) - buffer page $read_counter",TRACE);
					seek($fh,$string_location,0);
					read($fh,$string_buffer,length($searchfor));
					if ($string_buffer eq $searchfor) {
						seek($fh,$string_location,0);
						if ($flag_debug_no_op) {
							writelog("NO OP: Replacing '$searchfor' with '$replace' at $string_location",TRACE);
						} else {
							writelog("Replacing '$searchfor' with '$replace' at $string_location",TRACE);
							print $fh $replace;
						}
						$replace_counter++;
					}
				} else {
					$flag_search = 0;
				}
			}

			# EOF Checks

			if (length($buffer) <= $read_buffer_size) {
				writelog("Buffer is smaller or equal to read buffer size",TRACE);	
				if (eof($fh)) {
					$flag_eof = 1;
				}
				if (length($buffer) == $read_buffer_size) {
					$flag_eof = 1;
				}
				if ($flag_eof) {
					$flag_loop = 0;
				}
			} else {
				if ($use_jumpback) {
					$jump_back = length($searchfor) * 2;
					if ($file_pointer - $jump_back > 0) {
						writelog("Jumping back $jump_back bytes",TRACE);		
						$file_pointer = $file_pointer - $jump_back;
					}
				}
			}
		}
		writelog("'$pathname' is closed",TRACE);	
		close($fh);
	} else {
		writelog("ERROR: Could not open the asset file.");
	}

	if ($match_counter > 0) {
		if ($match_counter eq $replace_counter) {
			$retval = 1;
		}
	}

	if ($retval > 0) {
		writelog("Found $match_counter matches of '$searchfor', changed $replace_counter matches to '$replace'",DEBUG);
	} else {
		if ($retval == 0) {
			writelog(" Read Frames: $read_counter",TRACE);
			writelog("     Matches: $match_counter",TRACE);
			writelog("Replacements: $replace_counter",TRACE);
		}
	}

	return $retval;
}


#-----------------------------------------------------------
# Backup Copy
#-----------------------------------------------------------
sub backupFile{
	my $source = shift;
	my $target = shift;
	my $retval = -1;

	return $retval unless defined $source;
	return $retval unless defined $target;

	writelog("backupFile '$source' to '$target'",TRACE);

	if (-e $source) {
		$retval = copy($source,$target);
	}

	return $retval;
}

#-----------------------------------------------------------
# Restore Assets
#-----------------------------------------------------------
sub restoreAssets{
	my $retval = 0;
	my $tempret = 0;

	$tempret = 0;
	if (-e $pathname_republic_backup) {
		$tempret++;
	} else {
		writelog("$name_republic backup is missing!",TRACE);
	}

	if (-e $pathname_imperial_backup) {
		$tempret++;
	} else {
		writelog("$name_imperial backup is missing!",TRACE);
	}

	if ($tempret == $mod_file_count) {
		writelog("Backup files are present.",TRACE);	
	} else {
		writelog("One or more backup files are missing!");
		writelog("You will need to perform a repair from the launcher to restore the originals.");
		return $retval;
	}

	$tempret = 0;
	$tempret = isPatched($pathname_republic_backup,$replace_republic);
	if ($tempret > 0) {
		writelog("$name_republic backup is patched!",TRACE);
		$tempret++;
	}

	$tempret = isPatched($pathname_imperial_backup,$replace_imperial);
	if ($tempret > 0) {
		writelog("$name_imperial backup is patched!",TRACE);
		$tempret++;
	}	

	if ($tempret > 0) {
		writelog("One or more backups are patched versions!");
		writelog("You will need to perform a repair from the launcher to restore the originals.");
		return $retval;
	} else {
		writelog("Backup files are not patched",DEBUG);
	}

	writelog("Attempting to Restore Assets");

	writelog("Attempting to Restore Asset File: $name_republic");
	$tempret = backupFile($pathname_republic_backup,$pathname_republic_asset);
	if ($tempret > 0 ) {
		$retval++;
	} else {
		writelog("ERROR: Failed to Restore Asset File: $name_republic");
	}

	writelog("Attempting to Restore Asset File: $name_imperial");
	$tempret = backupFile($pathname_imperial_backup,$pathname_imperial_asset);
	if ($tempret > 0 ) {
		$retval++;
	} else {
		writelog("ERROR: Failed to Restore Asset File: $name_imperial");
	}

	if ($retval == $mod_file_count) {
		writelog("Restore Successful!");
		$retval = 1;
	} else {
		writelog("Restore Failed!");
		writelog("You may need to perform a repair from the launcher to restore the originals.");
		$retval = 0;
	}

	return $retval;
}

#-----------------------------------------------------------
# Read Data File
#-----------------------------------------------------------
sub readDataFile{
	my $pathname = shift;
	my $retval = -1;
	my $fh;
	my @content;
	my $datafile_name;
	my $datafile_marker;
	my $flag_default = 1;

	return $retval unless defined $pathname;
	
	writelog("readDataFile '$pathname'",TRACE);

	if (open($fh, "<", $pathname)) {
		writelog("'$pathname' is open as READ ONLY",TRACE);
		@content = <$fh>;
		writelog("'$pathname' is closed",TRACE);	
		close($fh);

		$buffer = $content[0];		# PROGRAM NAME
		chop $buffer;
		$datafile_name = $buffer;

		if ($datafile_name ne PROGRAM_NAME) {
			writelog("WARNING: Data file name does not match! ($datafile_name)",DEBUG);
		}

		$buffer = $content[1];		# VERSION
		chop $buffer;
		$datafile_version = $buffer;

		writelog("Data File created with version $datafile_version",TRACE);

		$buffer = $content[2];		# "DATA FILE"
		chop $buffer;
		$datafile_marker = $buffer;

		if ($buffer ne "DATA FILE") {
			writelog("WARNING: Data file chunk missing!",DEBUG);
		}

		#	Handle Specific Versions
		
		switch ($datafile_version) {
			case "201511161613"
				{
					$buffer = $content[3];		# gameroot
					chop $buffer;
					$stored_gameroot = $buffer;

					$buffer = $content[4];		# Assets Patch
					chop $buffer;
					$stored_version_patch = $buffer;

					$buffer = $content[5];		# Assets Data
					chop $buffer;
					$stored_version_data = $buffer;

					$buffer = $content[6];		# Republic Asset Hash
					chop $buffer;
					$stored_hash_asset_republic = $buffer;

					$buffer = $content[7];		# Imperial Asset Hash
					chop $buffer;
					$stored_hash_asset_imperial = $buffer;

					$buffer = $content[8];		# Is Patched
					chop $buffer;
					$stored_is_patched = $buffer;
	
					$flag_default = 0;
					$flag_update_datafile = 1;
				}
		}

		#	Standard Version 

		if ($flag_default) {
			$buffer = $content[3];		# gameroot
			chop $buffer;
			$stored_gameroot = $buffer;

			$buffer = $content[4];		# backuproot
			chop $buffer;
			$stored_backuproot = $buffer;

			$buffer = $content[5];		# Assets Patch
			chop $buffer;
			$stored_version_patch = $buffer;

			$buffer = $content[6];		# Assets Data
			chop $buffer;
			$stored_version_data = $buffer;

			$buffer = $content[7];		# Republic Asset Hash
			chop $buffer;
			$stored_hash_asset_republic = $buffer;

			$buffer = $content[8];		# Imperial Asset Hash
			chop $buffer;
			$stored_hash_asset_imperial = $buffer;

			$buffer = $content[9];		# Is Patched
			chop $buffer;
			$stored_is_patched = $buffer;
		}
	
		$retval = 1;		
		
	} else {
		writelog("Could not open '$pathname'",TRACE);	
	}
	
	if ($debug >= TRACE) {
		if ($retval) {
			writelog("***",TRACE);
			writelog("DATA FILE READ at '$pathname':",TRACE);
			writelog(" Data File Version: $datafile_version",TRACE);
			writelog("     Game Location: $stored_gameroot",TRACE);
			writelog("   Backup Location: $stored_backuproot",TRACE);
			writelog("       Asset Patch: $stored_version_patch",TRACE);
			writelog("        Asset Data: $stored_version_data",TRACE);
			writelog("      Republic MD5: $stored_hash_asset_republic",TRACE);
			writelog("      Imperial MD5: $stored_hash_asset_imperial",TRACE);
			writelog("Assets Are Patched: $stored_is_patched",TRACE);
			writelog("***",TRACE);
		} else {
			writelog("***",TRACE);
			writelog("DATA FILE FAILED READ at '$pathname':",TRACE);
			writelog("***",TRACE);
		}
	}


	return $retval;
}

#-----------------------------------------------------------
# Write Data File
#-----------------------------------------------------------
sub writeDataFile{
	my $pathname = shift;
	my $fh;
	my $retval = -1;

	return $retval unless defined $pathname;

	writelog("writeDataFile '$pathname'",TRACE);

	if (-e $pathname) {
		writelog("Deleting '$pathname'",TRACE);
		unlink $pathname;
	}

	if (open($fh, ">", $pathname)) {
		writelog("'$pathname' is open as WRITE",TRACE);
		print $fh PROGRAM_NAME . "\n";
		print $fh PROGRAM_VERSION . "\n";
		print $fh "DATA FILE\n";
		print $fh "$gameroot\n";
		print $fh "$backuproot\n";
		print $fh "$stored_version_patch\n";
		print $fh "$stored_version_data\n";
		print $fh "$stored_hash_asset_republic\n";
		print $fh "$stored_hash_asset_imperial\n";
		print $fh "$stored_is_patched\n";
		writelog("'$pathname' is closed",TRACE);	
		close($fh);
	} else {
		writelog("Could not open '$pathname'",TRACE);	
	}

	return $retval;
}


#-----------------------------------------------------------
# Get Asset Version
#-----------------------------------------------------------
sub getAssetVersion{
	my $pathname = shift;
	my $retval = "-1\|-1";
	my $ver_patch = "";
	my $ver_data = "";
	my $fh;
	my $buffer = "";

	return $retval unless defined $pathname;
	
	writelog("getAssetVersion using '$pathname'",TRACE);

	if (open($fh, "<", $pathname)) {
		writelog("'$pathname' is open as READ ONLY",TRACE);
		$buffer = <$fh>;
		chomp $buffer;
		writelog("'$pathname' is closed",TRACE);	
		close($fh);
	} else {
		writelog("Could not open '$pathname'",TRACE);	
	}


	$ver_patch = $buffer;
	$ver_data = $buffer;

	if ($ver_patch =~ /(\d+)/ ) {
		$ver_patch = $1;
	} else {
		$ver_patch = -1;
	}

	if ($ver_data =~ /(\d+\.\d+\.\d+)/ ) {
		$ver_data = $1;
	} else {
		$ver_data = -1;
	}

	$retval = "$ver_patch\|$ver_data";

	return $retval;
}

#-----------------------------------------------------------
# Get File Hash
#-----------------------------------------------------------
sub getFileHash{
	my $pathname = shift;
	my $hash = INVALID_HASH;
	my $fh;

	return $hash unless defined $pathname;

	writelog("getFileHash '$pathname'",TRACE);

	if (open($fh, "<", $pathname)) {
		binmode($fh);
		writelog("'$pathname' is open in binary mode as READ ONLY",TRACE);
		$hash = Digest::MD5->new->addfile($fh)->hexdigest;
		writelog("'$pathname' is closed",TRACE);	
		close($fh);
	} else {
		writelog("Could not open '$pathname'",TRACE);	
	}


	return $hash;
}

#-----------------------------------------------------------
# Show Version
#-----------------------------------------------------------
sub showVersion{
	exit(0);
}

#-----------------------------------------------------------
# Get Asset Hashes
#-----------------------------------------------------------
sub getAssetHashes{
	my $retval = 0;
	my $tempval = 0;
	my $temp_hash_asset_republic;
	my $temp_hash_asset_imperial;

	writelog("getAssetHashes Getting MD5 hashes for assets.",TRACE);
	writelog("Getting MD5 hash for $name_republic asset file.",TRACE);

	$temp_hash_asset_republic = getFileHash($pathname_republic_asset);
	if ($temp_hash_asset_republic eq INVALID_HASH) {
		writelog("ERROR: Failed to get MD5 hash for $name_republic asset file.",TRACE);
	} else {
		$tempval++;
	}
	
	writelog("Getting MD5 hash for $name_imperial asset file.",TRACE);	
	$temp_hash_asset_imperial = getFileHash($pathname_imperial_asset);
	if ($temp_hash_asset_imperial eq INVALID_HASH) {
		writelog("ERROR: Failed to get MD5 hash for $name_imperial asset file.",TRACE);
	} else {
		$tempval++;
	}	

	if ($tempval == $mod_file_count) {
		$retval = 1;
		$hash_asset_republic = $temp_hash_asset_republic;
		$hash_asset_imperial = $temp_hash_asset_imperial;

	} else {
		$retval = 0;
	}

	return $retval;

}


#-----------------------------------------------------------
# Compare Assets and Backups
#-----------------------------------------------------------
sub compareAssetsAndBackups{
	my $retval = 0;
	my $counter = 0;

	my $temp_hash_backup_republic = INVALID_HASH;
	my $temp_hash_backup_imperial = INVALID_HASH;
	my $temp_hash_asset_republic  = INVALID_HASH;
	my $temp_hash_asset_imperial = INVALID_HASH;

	writelog("compareAssetsAndBackups",TRACE);

	$temp_hash_backup_republic = getFileHash($pathname_republic_backup);
	$temp_hash_backup_imperial = getFileHash($pathname_imperial_backup);

	$temp_hash_asset_republic = getFileHash($pathname_republic_asset);
	$temp_hash_asset_imperial = getFileHash($pathname_imperial_asset);

	
	if ($temp_hash_backup_republic eq $temp_hash_asset_republic) {
		if ($temp_hash_asset_republic ne INVALID_HASH) {
			$counter++;
		}
	}

	if ($temp_hash_backup_imperial eq $temp_hash_asset_imperial) {
		if ($temp_hash_asset_imperial ne INVALID_HASH) {
			$counter++;
		}
	}
	
	if ($counter == $mod_file_count) {
		$retval = 1;
	}
		
	return $retval;

}

#-----------------------------------------------------------
# verifyAssetFiles (by Hash)
#-----------------------------------------------------------
sub verifyAssetFiles{
	my $retval = 0;

	writelog("verifyAssetFiles",TRACE);

	if (getAssetHashes()) {
		if ($stored_hash_asset_republic ne INVALID_HASH) {
			if ($stored_hash_asset_republic eq $hash_asset_republic) {
				$retval++
			}
		}

		if ($stored_hash_asset_imperial ne INVALID_HASH) {
			if ($stored_hash_asset_imperial eq $hash_asset_imperial) {
				$retval++
			}
		}
	}

	return $retval;
}


#-----------------------------------------------------------
# Show Tips
#-----------------------------------------------------------
sub showTips{
	writelog("* Manually copy assets from backup folder to game assets folder");
	writelog("* Run this tool with -restore option");
	writelog("* Perform a repair from the launcher");
	return;
}

#-----------------------------------------------------------
# Command: Restore Operation
#-----------------------------------------------------------
sub optRestoreOperation{
	if ($flag_backups_exist < $mod_file_count) {
		writelog("Restore function is not available because backups are not present!");
		writelog();
		if ($no_backup) {
			writelog("The -nobackup flag is enabled.");
		}
		writelog();
		writelog("Possible Causes:");
		writelog("* The -nobackup flag was used previously.");
		writelog("* The backup function failed.");
		writelog();
		writelog("If you wish to restore your asset files you will need to:");
		writelog("* Copy them from your own backup");
		writelog("* Perform a repair in the $game_name launcher");
	} else {

		# 	Determine to see if a restore is required

		$reason = "Unknown";

		if ($flag_data_file_read) {
			
			# 	If we have the stored asset checksums, verify them

			$flag_asset_checksum_match = verifyAssetFiles();

			if ($flag_asset_checksum_match == $mod_file_count) {
				$reason = "Asset checksums already match the original files.";
				$flag_skip_restore = 1;
			}
		}

		if ($flag_skip_restore == 0) {

			# 	See if the assets are patched

			$flag_assets_already_patched = assetsPatched();

			if ($flag_assets_already_patched == 0) {
				$reason = "Asset files have not been patched.";
				$flag_skip_restore = 1;
			}
		}

		if ($flag_skip_restore == 0) {
	
			#	Last restore, do md5 comparisons of the asset and backup files,
			#	if they match, there's no point

			if (compareAssetsAndBackups()) {
				$reason = "Asset and backup files are identical.";
				$flag_skip_restore = 1;
			}
		}

		if ($flag_skip_restore) {
			writelog("Restore not required: $reason");
		} else {
			if (restoreAssets()) {
				$flag_assets_verified = 0;
				$reason = "Unknown";

				writelog("Determining success of restoration",TRACE);

				if ($flag_data_file_read) {
					writelog("Verifying Assets for Data File",TRACE);
	
					$flag_asset_checksum_match = verifyAssetFiles();
	
					if ($flag_asset_checksum_match == $mod_file_count) {
						writelog("Asset hashes match the originals",TRACE);
						$stored_is_patched = 0;
						$flag_assets_verified = $flag_assets_verified + $flag_asset_checksum_match;
					} else {
						$reason = "Assets may still be patched!  Checksums do not match.";
					}
				} else {
					writelog("No Data File",TRACE);
				}

				$flag_assets_already_patched = assetsPatched();

				if ($flag_assets_already_patched == $mod_file_count) {
					$reason = "Assets are still patched!";
					$stored_is_patched = 1;
					$flag_assets_verified = 0;
				} else {
					if ($flag_assets_already_patched == 0 ) {
						$flag_assets_verified = $flag_assets_verified + $mod_file_count;
					}
					if ($flag_assets_already_patched == 1 ) {
						$flag_assets_verified = $flag_assets_verified + 1;
						$reason = "At least one asset is still patched!";
					}
					$stored_is_patched = 0;
				}

				if ($flag_assets_verified > 0) {
					writelog("Assets Verified, Certainty is " . $flag_assets_verified * 25 . "%");
				} else {
					writelog("WARNING: $reason");
				}
	
				if ($no_datafile > 0) {
					#	No Data File
				} else {
					writelog("Updating Data File '$pathname_datafile'",TRACE);
	
					$retval = writeDataFile($pathname_datafile);
	
					if ($retval) {
						writelog("Data File Written OK",DEBUG);
						$flag_update_datafile = 0;
					} else {
						writelog("ERROR: Could not write data file.");
					}
				}
			} else {
				writelog("restoreAssets failed",TRACE);
			}
		}
		
	}
	$flag_exit = 1;
	return;
}

#-----------------------------------------------------------
# Show Help
#-----------------------------------------------------------
sub showHelp{
	writelog("This mod will silence the audio for the ship droids");
	writelog("in the game '$game_name'.");
	writelog();
	writelog();
	writelog("Commands and Options:");	
	writelog();
	writelog("-restore 		restore from backups (invalid if -nobackup is used)");
	writelog("-nobackup 		don't use backups");
	writelog("-nodatafile 		don't use data file");
	writelog("-version		show version");
 	writelog("-debug / -trace		show debug / trace messages");
	writelog("-help			this screen");
	writelog();
	writelog();
	writelog("Optional:");
	writelog();
	writelog("-backup folder		specify backup folder");
	writelog("-game folder		specify game folder");
	writelog("-data folder		specify data folder");
	writelog();
	exit(0);
}
