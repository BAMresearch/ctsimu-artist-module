package require TclOO
package require fileutil
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_part.tcl]

# A class to manage and set up a complete CTSimU scenario,
# includes e.g. all coordinate systems, etc.

namespace eval ::ctsimu {
	namespace import ::rl_json::*

	::oo::class create scenario {
		constructor { } {
			# State
			my variable running
			my variable batch_is_running
			my variable json_loaded_successfully

			my set_run_status        0
			my set_batch_run_status 0

			# Settings
			my variable _settings;  # dictionary with simulation settings
			set _settings [dict create]


			# Output settings
			my variable output_fileformat; # "tiff" or "raw"
			my variable output_datatype;   # 16 bit uint, 32 bit float
			my variable output_folder
			my variable output_basename

			my variable create_cera_config_file
			my variable create_clfdk_config_file

			my variable projection_counter_format;  # minimum digit format for projection files

			my setFileFormat        "tiff"
			my setDataType          "16bit"
			my setBasename          "proj_"
			my setOutputFolder      ""
			my setCreateCERAconfigFile  1
			my setCreateCLFDKconfigFile 1


			# Geometry: coordinate systems and their drifts
			my variable csWorld
			my variable csFocus
			my variable csStage
			my variable csDetector
			my variable csSamples

			# Acquisition parameters
			my variable jsonfile;           # currently loaded JSON file
			my variable startAngle;         # angle where CT rotation starts
			my variable stopAngle;          # angle where CT rotation stops
			my variable nProjections;       # total number of projections for CT scan
			my variable projNr;             # current projection number of the scene
			my variable includeFinalAngle;  # 0 or 1: take the last projection at the stop angle?
			my variable startProjNr;        # projection number where to pick up CT scan (useful if a simulation crashed)

			my variable takeDarkField; # 0 or 1: take a dark field image? (typically noise-free in aRTist)
			my variable nDarks;        # number of dark field images to create
			my variable nFlats;        # number of flat field images to create
			my variable nFlatAvg;      # number of frame averages for a flat field image
			my variable ffIdeal;       # take ideal (noise-free) flat field image?

			set csWorld    [::ctsimu::coordinate_system new]
			set csCERA     [::ctsimu::coordinate_system new]
			$csCERA make 0 0 0 -1 0 0 0 0 1 0

			set csFocus    [::ctsimu::part new]
			set csStage    [::ctsimu::part new]
			set csDetector [::ctsimu::part new]
			set csSamples  [list]

			my reset
		}

		destructor {
			my variable csWorld csCERA csFocus csStage csDetector csSamples

			$csWorld destroy
			$csCERA destroy
			$csFocus destroy
			$csStage destroy
			$csDetector destroy
			foreach sample $csSamples {
				$sample destroy
			}
		}

		method reset { } {
			my variable _settings csFocus csStage csDetector csSamples

			# Initial values after a reset.
			my set_json_load_status    0

			my setJsonfile          ""
			my setStartAngle        0
			my setStopAngle         360
			my setNprojections      2000
			my setProjNr            0
			my setIncludeFinalAngle 0
			my setStartProjNr       0

			my setTakeDarkField     0
			my setDarks             1
			my setFlats             1
			my setFlatAvg           20
			my setFFideal           0

			# Delete all existing samples:
			foreach sample $csSamples {
				$sample destroy
			}

			set csSamples  [list]
			$csFocus reset
			$csStage reset
			$csDetector reset
		}

		# Getters
		method get { setting } {
			# Get a settings value from the settings dict
			my variable _settings
			return [dict get $_settings $setting]
		}

		method is_running { } {
			my variable running
			return $running
		}

		method batch_is_running { } {
			my variable batch_is_running
			return $batch_is_running
		}

		method json_loaded_successfully { } {
			my variable json_loaded_successfully
			return $json_loaded_successfully
		}

		method file_format { } {
			my variable output_fileformat
			return $output_fileformat
		}

		method data_type { } {
			my variable output_datatype
			return $output_datatype
		}

		method basename { } {
			my variable output_basename
			return $output_basename
		}

		method output_folder { } {
			my variable output_folder
			return $output_folder
		}

		method create_cera_config_file { } {
			my variable create_cera_config_file
			return $create_cera_config_file
		}

		method create_clfdk_config_file { } {
			my variable create_clfdk_config_file
			return $create_clfdk_config_file
		}

		method projection_counter_format { } {
			my variable projection_counter_format
			return $projection_counter_format
		}

		method jsonfile { } {
			my variable jsonfile
			return $jsonfile
		}

		method startAngle { } {
			my variable startAngle
			return $startAngle
		}

		method stopAngle { } {
			my variable stopAngle
			return $stopAngle
		}

		method nProjections { } {
			my variable nProjections
			return $nProjections
		}

		method projNr { } {
			my variable projNr
			return $projNr
		}

		method includeFinalAngle { } {
			my variable includeFinalAngle
			return $includeFinalAngle
		}

		method startProjNr { } {
			my variable startProjNr
			return $startProjNr
		}

		method takeDarkField { } {
			my variable takeDarkField
			return $takeDarkField
		}

		method nDarks { } {
			my variable nDarks
			return $nDarks
		}

		method nFlats { } {
			my variable nFlats
			return $nFlats
		}

		method nFlatAvg { } {
			my variable nFlatAvg
			return $nFlatAvg
		}

		method ffIdeal { } {
			my variable ffIdeal
			return $ffIdeal
		}


		# Setters
		method set { setting value } {
			# Set a settings value in the settings dict
			my variable _settings
			dict set _settings $setting $value
		}

		method set_run_status { r } {
			my variable running
			set running $r
		}

		method set_batch_run_status { r } {
			my variable batch_is_running
			set batch_is_running $r
		}

		method set_json_load_status { status } {
			my variable json_loaded_successfully
			set json_loaded_successfully $status
		}

		method setFileFormat { fileformat } {
			my variable output_fileformat
			set output_fileformat $fileformat
		}

		method setDataType { datatype } {
			my variable output_datatype
			set output_datatype $datatype
		}

		method setBasename { name } {
			my variable output_basename
			set output_basename $name
		}

		method setBasenameFromJSON { jsonfilename } {
			set baseName [file root [file tail $jsonfilename]]
			set outputBaseName $baseName
			#append outputBaseName "_aRTist"
			my setBasename $outputBaseName
		}

		method setOutputFolder { folder } {
			my variable output_folder
			set output_folder $folder
		}

		method setOutputFolderFromJSON { jsonfilename } {
			my setOutputFolder [file dirname "$jsonfilename"]
		}

		method setCreateCERAconfigFile { ceraCfgFile } {
			my variable create_cera_config_file
			set create_cera_config_file $ceraCfgFile
		}

		method setCreateCLFDKconfigFile { clfdkCfgFile } {
			my variable create_clfdk_config_file
			set create_clfdk_config_file $clfdkCfgFile
		}

		method setProjectionCounterFormat { nProjections } {
			# Sets the number format string to get the correct
			# number of digits in the consecutive projection file names.
			my variable projection_counter_format

			set digits 4

			# For anything bigger than 10000 projections (0000 ... 9999) we need more filename digits.
			if { $nProjections > 10000 } {
				set digits [expr int(ceil(log10($nProjections)))]
			}

			set projection_counter_format "%0"
			append projection_counter_format $digits
			append projection_counter_format "d"
		}

		method setJsonfile { jf } {
			my variable jsonfile
			set jsonfile $jf
		}

		method setStartAngle { sa } {
			my variable startAngle
			set startAngle $sa
		}

		method setStopAngle { sa } {
			my variable stopAngle
			set stopAngle $sa
		}

		method setNprojections { nproj } {
			my variable nProjections
			set nProjections $nproj

			my setProjectionCounterFormat $nproj
		}

		method setProjNr { pn } {
			my variable projNr
			set projNr $pn
		}

		method setIncludeFinalAngle { fa } {
			my variable includeFinalAngle
			set includeFinalAngle $fa
		}

		method setStartProjNr { spn } {
			my variable startProjNr
			set startProjNr $spn
		}

		method setTakeDarkField { tdf } {
			my variable takeDarkField
			set takeDarkField $tdf
		}

		method setDarks { nd } {
			my variable nDarks
			set nDarks $nd
		}

		method setFlats { nf } {
			my variable nFlats
			set nFlats $nf
		}

		method setFlatAvg { favg } {
			my variable nFlatAvg
			set nFlatAvg $favg
		}

		method setFFideal { ffi } {
			my variable ffIdeal
			set ffIdeal $ffi
		}

		method setup_json_scene { jsonfilename } {
			my variable csWorld csFocus csStage csDetector csSamples

			my reset; # also sets JSON load status to 0 (not yet successful)

			global Xsource_private

			# clear global lists:
			#set ctsimuSettings {}
			set ctsimuSamples {}
			set ctsimuSceneMaterials {}

			set jsonfiledir [file dirname "$jsonfilename"]

			set jsonfile [open $jsonfilename r]
			fconfigure $jsonfile -encoding utf-8
			set jsonstring [read $jsonfile]
			close $jsonfile

			# Set output folder and basename for projections:
			my setOutputFolderFromJSON $jsonfilename
			my setBasenameFromJSON $jsonfilename

			set scene $jsonstring
			set scenarioName "CTSimU"

			if {[json exists $scene file file_type]} {
				set filetype [::ctsimu::get_value $scene {file file_type}]
				if {$filetype == "CTSimU Scenario"} {

					# Check if file format version exists
					if {([json exists $scene file version major] && [json exists $scene file version minor]) || ([json exists $scene file file_format_version major] && [json exists $scene file file_format_version minor])} {
						
						# Check version to correctly interpret JSON
						set version_major [::ctsimu::get_value $scene {file file_format_version major}]
						set version_minor [::ctsimu::get_value $scene {file file_format_version minor}]

						if {($version_major == "null") && ($version_minor == "null")} {
							set version_major [::ctsimu::get_value $scene {file version major}]
							set version_minor [::ctsimu::get_value $scene {file version minor}]
						}

						# Parsing for version 0.3 to 0.9:
						if {$version_major == 0 && ( $version_minor == 3 || $version_minor == 4 || $version_minor == 5 || $version_minor == 6 || $version_minor == 7 || $version_minor == 8 || $version_minor == 9 )} {
							aRTist::Info { "Scenario Version $version_major.$version_minor" }

							set scenarioName [::ctsimu::get_value $scene {file name}]

							# Geometry dictionaries for detector, source and stage (from JSON)
							set detectorGeometry 0
							set sourceGeometry 0
							set stageGeometry 0

							showInfo "Setting up geometry..."

							# Set up stage:
							if [json exists $scene geometry stage] {
								set stageGeometry [json extract $scene geometry stage]
								$csStage set_geometry $stageGeometry $csWorld $csWorld
							} else {
								fail "Cannot find stage geometry."
								return
							}

							# Set up detector geometry:
							if [json exists $scene geometry detector] {
								set detectorGeometry [json extract $scene geometry detector]
								$csDetector set_geometry $detectorGeometry $csWorld $csStage
							} else {
								fail "Cannot find detector geometry."
								return
							}

							# Set up source geometry:
							if [json exists $scene geometry source] {
								set sourceGeometry [json extract $scene geometry source]
								set csSource [makeCoordinateSystemFromGeometry S $sourceGeometry $csStage]
								aRTist_placeObjectInCoordinateSystem S $csSource
								dict set ctsimuSettings csSource $csSource
							} else {
								fail "Cannot find source geometry."
								return
							}


							# Centre points
							set S [dict get $csSource centre]
							set O [dict get $csStage centre]
							set D [dict get $csDetector centre]

							# Source centre:
							set xS [lindex $S 0]
							set yS [lindex $S 1]
							set zS [lindex $S 2]

							# Detector centre and coordinate system
							set xD [lindex $D 0]
							set yD [lindex $D 1]
							set zD [lindex $D 2]
							set uD [vec3Unit [dict get $csDetector u]]
							set vD [vec3Unit [dict get $csDetector v]]
							set wD [vec3Unit [dict get $csDetector w]]

							# Stage coordinate system
							set uO [vec3Unit [dict get $csStage u]]
							set vO [vec3Unit [dict get $csStage v]]
							set wO [vec3Unit [dict get $csStage w]]

							# Centre of stage is transformed to be at origin (0, 0, 0).
							# New centre of source in world CS:
							set rfoc [vec3Diff $S $O]

							# New centre of source in stage CS (which is world CS as far as the projection matrix is concerned):
							set m_worldToStage [basis_transform_matrix $csWorld $csStage]

							set rfoc_in_stageCS [::math::linearalgebra::matmul $m_worldToStage $rfoc]

							set xfoc [lindex $rfoc_in_stageCS 0]
							set yfoc [lindex $rfoc_in_stageCS 1]
							set zfoc [lindex $rfoc_in_stageCS 2]

							# Focus point on detector,
							# i.e. intersection of Source->Stage vector with detector plane.
							# clFDK assumes detector (u, v) coordinate system in mm units,
							# origin at detector centre, u points "right", v points "down".
							
							# Focus unit vector, pointing from source to stage,
							# will intersect with detector plane (hopefully ;-)
							set efoc [vec3Unit [vec3Diff $O $S]]
							set efoc_x [lindex $efoc 0]
							set efoc_y [lindex $efoc 1]
							set efoc_z [lindex $efoc 2]

							# Detector normal:
							set nx [lindex $wD 0]
							set ny [lindex $wD 1]
							set nz [lindex $wD 2]

							# The SDD in this concept means the distance between the source S
							# and the intersection point of vector efoc with the detector plane.
							set E [expr $nx*$xD + $ny*$yD + $nz*$zD]
							set SDD [expr ($E - $xS*$nx - $yS*$ny - $zS*$nz)/($nx*$efoc_x + $ny*$efoc_y + $nz*$efoc_z)]




							# SDD and SOD:
							set SDDcentre2centre [expr abs([vec3Dist $S $D])]
							set SOD [expr abs([vec3Dist $S $O])]
							set ODD [expr abs($SDD - $SOD)]
							dict set ctsimuSettings SOD $SOD
							dict set ctsimuSettings SDDcentre2centre $SDDcentre2centre
							dict set ctsimuSettings SDD $SDD
							dict set ctsimuSettings ODD $ODD
							#dict set ctsimuSettings stageCenterOnDetectorU $stageCenterOnDetectorU
							#dict set ctsimuSettings stageCenterOnDetectorV $stageCenterOnDetectorV

							# Save a source CS as seen from the detector CS. This is convenient to
							# later get the SDD, ufoc and vfoc:
							set sourceFromDetector [change_reference_frame $csSource $csWorld $csDetector]
							set stageFromDetector [change_reference_frame $csStage $csWorld $csDetector]

							# Focus point on detector: principal, perpendicular ray.
							# In the detector coordinate system, ufoc and vfoc are the u and v coordinates
							# of the source center; SDD (perpendicular to detector plane) is source w coordinate.
							set sourceCenterInDetectorCS [dict get $sourceFromDetector centre]
							set stageCenterInDetectorCS [dict get $stageFromDetector centre]

							#set ufoc [lindex $sourceCenterInDetectorCS 0]
							#set vfoc [lindex $sourceCenterInDetectorCS 1]
							set SDDbrightestSpot [lindex $sourceCenterInDetectorCS 2]
							set SDDbrightestSpot [expr abs($SDDbrightestSpot)]
							set SODbrightestSpot [lindex $stageCenterInDetectorCS 2]
							set SODbrightestSpot [expr abs($SODbrightestSpot)]

							aRTist::Info {"SDD: $SDD"}
							aRTist::Info {"SDD center to center: $SDDcentre2centre"}
							aRTist::Info {"SDD brightest spot: $SDDbrightestSpot"}
							aRTist::Info {"Stage on Detector u: $stageCenterOnDetectorU"}
							aRTist::Info {"Stage on Detector v: $stageCenterOnDetectorV"}

							dict set ctsimuSettings SDDbrightestSpot $SDDbrightestSpot
							dict set ctsimuSettings SODbrightestSpot $SODbrightestSpot
							#dict set ctsimuSettings ufoc $ufoc
							#dict set ctsimuSettings vfoc $vfoc

							# Set up materials:
							showInfo "Setting up materials..."
							if [json exists $scene materials] {
								json foreach mat [json extract $scene materials] {
									if {[json exists $mat id] && [json exists $mat density value] && [json exists $mat composition] && [json exists $mat name]} {
										addMaterial [json get $mat id] [in_g_per_cm3 [json extract $mat density]] [json get $mat composition] [json get $mat name]
									}
								}
							}

							# Samples must be loaded to be centreed at (0, 0, 0):
							set ::aRTist::LoadCentreed 1

							# Import samples:
							showInfo "Importing samples..."
							if {![json isnull $scene samples]} {
								if [json exists $scene samples] {
									set samplesDict [json extract $scene samples]
									#set nSamples [json length $samplesDict]
									#aRTist::Info { "$nSamples samples found." }

									set i 1
									json foreach sample $samplesDict {
										if {$sample != "null"} {
											set STLfilename [json get $sample file]
											set STLname [json get $sample name]
											set STLpath $jsonfiledir
											append STLpath "/$STLfilename"
											aRTist::Info { "STL found: $STLpath"}

											set id $i
											set sampleMaterial "Al"
											if [json exists $sample material_id] {
												set sampleMaterial [getMaterialID [json get $sample material_id]]
											}

											set id [::PartList::LoadPart "$STLpath" "$sampleMaterial" "$STLname" yes]

											set sampleGeometry [json extract $sample position]
											set csSample [makeCoordinateSystemFromGeometry $id $sampleGeometry $csStage]
											aRTist_placeObjectInCoordinateSystem $id $csSample

											# Scale according to JSON:
											set scaleX 1
											set scaleY 1
											set scaleZ 1

											if {[json exists $sample scaling_factor r]} {
												set scaleX [json get $sample scaling_factor r]
											}

											if {[json exists $sample scaling_factor s]} {
												set scaleY [json get $sample scaling_factor s]
											}

											if {[json exists $sample scaling_factor t]} {
												set scaleZ [json get $sample scaling_factor t]
											}

											set objectSize [::PartList::Invoke $id GetSize]

											set sizeX [expr $scaleX*[lindex $objectSize 0]]
											set sizeY [expr $scaleY*[lindex $objectSize 1]]
											set sizeZ [expr $scaleZ*[lindex $objectSize 2]]

											::PartList::Invoke $id SetSize $sizeX $sizeY $sizeZ

											# Make sample object, consisting of original size and coordinate system:
											set sampleObject [dict create coordinates $csSample originalSizeX $sizeX originalSizeY $sizeY originalSizeZ $sizeZ]

											puts "Appending to ctsimuSamples."
											lappend ctsimuSamples $sampleObject

											incr i
										}
									}
								}
							}

							# Set environment material:
							if [json exists $scene environment material_id] {
								set environmentMaterial [getMaterialID [json get $scene environment material_id]]
								set ::Xsetup(SpaceMaterial) $environmentMaterial
							}

							# Acquisition parameters:
							showInfo "Setting acquisition parameters..."
							if [json exists $scene acquisition start_angle] {
								$ctsimu_scenario setStartAngle [in_deg [json extract $scene acquisition start_angle]]
							} else {
								fail "Start angle not specified."
								return
							}

							if [json exists $scene acquisition stop_angle] {
								$ctsimu_scenario setStopAngle [in_deg [json extract $scene acquisition stop_angle]]
							} else {
								fail "Stop angle not specified."
								return
							}

							
							if [json exists $scene acquisition angular_steps] {
								# Format version 0.3:
								setnProjections [json get $scene acquisition angular_steps]
							} elseif [json exists $scene acquisition number_of_projections] {
								# Format version >=0.4:
								setnProjections [json get $scene acquisition number_of_projections]
							} else {
								fail "Number of resulting projections not specified."
								return
							}

							if [json exists $scene acquisition direction] {
								setScanDirection [json get $scene acquisition direction]
							} else {
								fail "Scan direction not specified."
								return
							}

							if [json exists $scene acquisition include_final_angle] {
								# Format version >=0.4:
								puts "Include final angle:"
								puts [from_bool [json get $scene acquisition include_final_angle]]
								setIncludeFinalAngle [from_bool [json get $scene acquisition include_final_angle]]
							} elseif [json exists $scene acquisition projection_at_final_angle] {
								# Format version 0.3:
								puts "Include final angle:"
								puts [from_bool [json get $scene acquisition projection_at_final_angle]]
								setIncludeFinalAngle [from_bool [json get $scene acquisition projection_at_final_angle]]
							} else {
								setIncludeFinalAngle 0
							}

							setProjNr 0

							# Source setup
							showInfo "Setting source parameters..."
							# Spectrum
							if [json exists $scene source spectrum monochromatic] {
								if {[from_bool [json get $scene source spectrum monochromatic]] == 1} {
									set ::Xsource(Tube) Mono
								}
							}

							if [json exists $scene source spectrum bremsstrahlung] {
								if {[from_bool [json get $scene source spectrum bremsstrahlung]] == 1} {
									set ::Xsource(Tube) General
								}
							}

							if [json exists $scene source spectrum characteristic] {
								if {[from_bool [json get $scene source spectrum characteristic]] == 1} {
									set ::Xsource(Tube) General
								}
							}

							set ::Xsource(Resolution) 0.5


							# Voltage and Current
							set current 0
							if [json exists $scene source current] {
								set current [in_mA [json extract $scene source current]]
								set ::Xsource(Exposure) $current
							}

							set voltage 0
							if [json exists $scene source voltage] {
								set voltage [in_kV [json extract $scene source voltage]]
								set ::Xsource(Voltage) $voltage
							}

							# Target
							if [json exists $scene source target type] {
								if { [json get $scene source target type] == "transmission" } {
									set ::Xsource(Transmission) 1
								} else {
									set ::Xsource(Transmission) 0
								}
							}
							
							if [json exists $scene source target material_id] {
								set ::Xsource(TargetMaterial) [getMaterialID [json get $scene source target material_id]]
							}

							if [json exists $scene source target thickness] {
								if {[object_value_is_null_or_zero [json extract $scene source target thickness]] == 0} {
									set ::Xsource(TargetThickness) [in_mm [json extract $scene source target thickness]]
								}
							}

							if [json exists $scene source target angle incidence value] {
								set ::Xsource(AngleIn) [in_deg [json extract $scene source target angle incidence]]
							}

							if [json exists $scene source target angle emission value] {
								set ::Xsource(TargetAngle) [in_deg [json extract $scene source target angle emission]]
							}

							set tubeName $scenarioName
							append tubeName " Tube"
							set tubeManufacturer ""
							set tubeModel ""
							if {[json exists $scene source manufacturer]} {
								set tubeManufacturer [json get $scene source manufacturer]
							}
							if {[json exists $scene source model]} {
								set tubeModel [json get $scene source model]
							}
							if { $tubeManufacturer != "" } {
								set tubeName $tubeManufacturer
							}
							if { $tubeModel != "" } {
								if { $tubeManufacturer != "" } {
									append tubeName " "
									append tubeName $tubeModel
								} else {
									set tubeName $tubeModel
								}
							}
							puts "Setting tube name to $tubeName"
							set ::Xsource(Name) $tubeName

							# Source filters
							# Generate filter list:
							set xraySourceFilters {}
							set windowFilters {}

							if {$version_major == 0 && ( $version_minor == 3 || $version_minor == 4 || $version_minor == 5)} {
								if [json exists $scene source filters] {
									set i 0
									json foreach mat [json extract $scene source filters] {
										if { $mat != "null" } {
											if {$i == 0} {
												# First material in the source filters list is the window:
												if [json exists $mat material_id] {
													set ::Xsource(WindowMaterial) [getMaterialID [json get $mat material_id]]
													if [json exists $mat thickness value] {
														set ::Xsource(WindowThickness) [in_mm [json extract $mat thickness]]
														lappend windowFilters [getMaterialID [json get $mat material_id]]
														lappend windowFilters [in_mm [json extract $mat thickness]]
													}
												}
												
											} elseif { $i == 1 } {
												# Second material in the source filters list is the filter material:
												if [json exists $mat material_id] {
													set ::Xsource(FilterMaterial) [getMaterialID [json get $mat material_id]]
													if [json exists $mat thickness value] {
														set ::Xsource(FilterThickness) [in_mm [json extract $mat thickness]]
														lappend xraySourceFilters [getMaterialID [json get $mat material_id]]
														lappend xraySourceFilters [in_mm [json extract $mat thickness]]
													}
												}
											} else {
												# Further filters:
												if [json exists $mat material_id] {
													if [json exists $mat thickness value] {
														lappend xraySourceFilters [getMaterialID [json get $mat material_id]]
														lappend xraySourceFilters [in_mm [json extract $mat thickness]]
													}
												}
											}

											incr i
										}
									}
								}
							} else {
								# From 0.6 on, the window and filters are separate entries.
								if [json exists $scene source window] {
									set i 0
									json foreach mat [json extract $scene source window] {
										if {$i == 0} {
											if [json exists $mat material_id] {
												set ::Xsource(WindowMaterial) [getMaterialID [json get $mat material_id]]
												if [json exists $mat thickness value] {
													set ::Xsource(WindowThickness) [in_mm [json extract $mat thickness]]
												}
											}
										}

										if [json exists $mat material_id] {
											if [json exists $mat thickness value] {
												lappend windowFilters [getMaterialID [json get $mat material_id]]
												lappend windowFilters [in_mm [json extract $mat thickness]]
											}
										}

										incr i
									}
								}

								if [json exists $scene source filters] {
									set i 0
									json foreach mat [json extract $scene source filters] {
										if {$i == 0} {
											if [json exists $mat material_id] {
												set ::Xsource(FilterMaterial) [getMaterialID [json get $mat material_id]]
												if [json exists $mat thickness value] {
													set ::Xsource(FilterThickness) [in_mm [json extract $mat thickness]]
												}
											}								
										}

										if [json exists $mat material_id] {
											if [json exists $mat thickness value] {
												lappend xraySourceFilters [getMaterialID [json get $mat material_id]]
												lappend xraySourceFilters [in_mm [json extract $mat thickness]]
											}
										}

										incr i
									}
								}
							}

							# New spectrum: use from file?
							set usingSpectrumFile 0
							if [json exists $scene source spectrum file] {
								set filename [json get $scene source spectrum file]
								if {$filename != "null" } {
									set fullpath $jsonfiledir
									append fullpath "/$filename"
									
									set usingSpectrumFile 1
									showInfo "Loading spectrum file..."

									if {$version_major == 0 && ( $version_minor == 3 || $version_minor == 4 || $version_minor == 5)} {
										# File versions prior to 0.6 assume that spectrum from file
										# is already filtered by all filters and the source window.
										::XSource::LoadSpectrum $fullpath
									} else {
										# File versions from 0.6 on assume that spectrum file is only filtered by window material.
										# Filter by any additional filters (JSON supports more than one filter)
										LoadSpectrum $fullpath $windowFilters $xraySourceFilters
									}
								}
							}

							# Compute new spectrum
							if {$usingSpectrumFile == 0} {
								showInfo "Computing spectrum..."
								ComputeSpectrum $windowFilters $xraySourceFilters
							}

							# Spot size
							showInfo "Setting spot intensity profile..."

							set sigmaX    [::ctsimu::getValueInMM $scene {source spot sigma u}]
							set sigmaY    [::ctsimu::getValueInMM $scene {source spot sigma v}]
							set spotSizeX [::ctsimu::getValueInMM $scene {source spot size u}]
							set spotSizeY [::ctsimu::getValueInMM $scene {source spot size v}]

							# If a finite spot size is provided, but no Gaussian sigmas,
							# the spot size is assumed to be the Gaussian width.
							if { [value_is_null_or_zero $sigmaX] } {
								aRTist::Info { "sigmaX is null or 0, retreating to spotSizeX." }
								set sigmaX $spotSizeX
							}
							if { [value_is_null_or_zero $sigmaY] } {
								aRTist::Info { "sigmaY is null or 0, retreating to spotSizeY." }
								set sigmaY $spotSizeY
							}

							if { [value_is_null_or_zero $sigmaX] || [value_is_null_or_zero $sigmaY] } {
								# Point source
								aRTist::Info { "sigmaX=0 or sigmaY=0. Setting point source." }
								
								set Xsource_private(SpotWidth) 0
								set Xsource_private(SpotHeight) 0
								set ::Xsetup_private(SGSx) 0
								set ::Xsetup_private(SGSy) 0
								set ::Xsetup(SourceSampling) point

								::XSource::SelectSpotType

								# Set detector multisampling to achieve partial volume effect:
								set ::Xsetup(DetectorSampling) 3x3
								#set ::Xsetup(DetectorSampling) {source dependent}
							} else {
								# Source multisampling:
								# Create a Gaussian spot profile, and activate source-dependent
								# multisampling for the detector.
								makeGaussianSpotProfile $sigmaX $sigmaY
								set ::Xsetup(DetectorSampling) {source dependent}
							}

							# Override detector and spot multisampling, if defined in JSON:
							set multisampling_detector [::ctsimu::get_value $scene {simulation aRTist multisampling_detector}]
							if {$multisampling_detector != "null"} {
								set ::Xsetup(DetectorSampling) $multisampling_detector
							}

							set multisampling_source   [::ctsimu::get_value $scene {simulation aRTist multisampling_spot}]
							if {$multisampling_source != "null"} {
								set ::Xsetup(SourceSampling) $multisampling_source
								::XSource::SelectSpotType
							}

							::XSource::SourceSizeModified


							# Scattering
							showInfo "Setting up scattering..."
							if [json exists $scene acquisition scattering] {
								if { [from_bool [json get $scene acquisition scattering]] == 1 } {
									set ::Xscattering(Mode) McRay
									set ::Xscattering(AutoBase) min
									set ::Xscattering(nPhotons) 2e+007
								} else {
									set ::Xscattering(Mode) off
								}
							}

							set scattering_photons [::ctsimu::get_value $scene {simulation aRTist scattering_mcray_photons}]
							if {$scattering_photons != "null"} {
								set ::Xscattering(nPhotons) $scattering_photons
							}
							
							

							# Detector setup:
							showInfo "Setting up detector..."

							 # Set frame averaging to 1 for now:
							 set ::Xdetector(NrOfFrames) 1

							Preferences::Set Detector AutoVar Size
							set ::Xsetup_private(DGauto) Size
							::XDetector::SelectAutoQuantity

							set detectorName $scenarioName
							append detectorName " Detector"
							set detectorManufacturer ""
							set detectorModel ""
							if {[json exists $scene source manufacturer]} {
								set detectorManufacturer [json get $scene source manufacturer]
							}
							if {[json exists $scene source model]} {
								set detectorModel [json get $scene source model]
							}
							if { $detectorManufacturer != "" } {
								set detectorName $detectorManufacturer
							}
							if { $detectorModel != "" } {
								if { $detectorManufacturer != "" } {
									append detectorName " "
									append detectorName $detectorModel
								} else {
									set detectorName $detectorModel
								}
							}
							puts "Setting detector name to $detectorName"

							# Detector type:
							set detectorType "real"
							if [json exists $scene detector type] {
								set value [json get $scene detector type]
								if {$value == "ideal"} {
									set detectorType "ideal"
								} elseif {$value == "real"} {
									set detectorType "real"
								} else {
									fail "Unknown detector type: $value"
									return
								}
							}

							set pixelCountU 0
							set pixelCountV 0

							if [json exists $scene detector columns value] {
								set pixelCountU [json get $scene detector columns value]
								set ::Xsetup(DetectorPixelX) $pixelCountU
							}

							if [json exists $scene detector rows value] {
								set pixelCountV [json get $scene detector rows value]
								set ::Xsetup(DetectorPixelY) $pixelCountV
							}

							set ::Xsetup(SquarePixel) 0

							set detPixelSizeU 0
							if [json exists $scene detector pixel_pitch u] {
								set detPixelSizeU [in_mm [json extract $scene detector pixel_pitch u]]
								set ::Xsetup_private(DGdx) $detPixelSizeU
							}

							set detPixelSizeV 0
							if [json exists $scene detector pixel_pitch v] {
								set detPixelSizeV [in_mm [json extract $scene detector pixel_pitch v]]
								set ::Xsetup_private(DGdy) $detPixelSizeV
							}

							set scintillatorMaterialID ""
							if [json exists $scene detector scintillator material_id] {
								set scintillatorMaterialID [getMaterialID [json get $scene detector scintillator material_id]]
							}

							set scintillatorThickness 0
							if [json exists $scene detector scintillator thickness value] {
								set scintillatorThickness [in_mm [json extract $scene detector scintillator thickness]]
							}

							set integrationTime 0
							if [json exists $scene detector integration_time value] {
								set integrationTime [in_s [json extract $scene detector integration_time]]
								set ::Xdetector(AutoD) off
								set ::Xdetector(Scale) $integrationTime
							}

							::XDetector::UpdateGeometry %W

							# Detector Characteristics
							# Deactivate flat field correction (not done in aRTist for the CTSimU project)
							set ::Xdetector(FFCorrRun) 0
							::XDetector::FFCorrClearCmd

							set minEnergy 0
							set maxEnergy 1000
							# the SNR refers to 1 frame, not an averaged frame:
							set nFrames 1

							# Generate filter list:
							set frontPanelFilters {}
							if [json exists $scene detector filters front] {
								if {[value_is_null_or_zero [json extract $scene detector filters front]] == 0} {
									json foreach mat [json extract $scene detector filters front] {
										if {$mat != "null"} {
											lappend frontPanelFilters [getMaterialID [json get $mat material_id]]
											lappend frontPanelFilters [in_mm [json extract $mat thickness]]
										}
									}
								}
							}

							# Basic spatial resolution:
							set SRb "null"
							if [json exists $scene detector sharpness basic_spatial_resolution value] {
								set SRb [in_mm [json extract $scene detector sharpness basic_spatial_resolution]]
							}

							# Grey values:
							set bitDepth 16
							if [json exists $scene detector bit_depth value] {
								set bitDepth [json get $scene detector bit_depth value]
							}
							set maxGVfromDetector [expr pow(2, $bitDepth)-1]

							set GVatMin "null"
							if [json exists $scene detector grey_value imin value] {
								set GVatMin [json get $scene detector grey_value imin value]
							}

							set GVatMax "null"
							if [json exists $scene detector grey_value imax value] {
								set GVatMax [json get $scene detector grey_value imax value]
							}

							set GVfactor "null"
							if [json exists $scene detector grey_value factor value] {
								set GVfactor [json get $scene detector grey_value factor value]
							}

							set GVoffset "null"
							if [json exists $scene detector grey_value offset value] {
								set GVoffset [json get $scene detector grey_value offset value]
							}

							# Signal to noise ratio (SNR)
							set SNRatImax "null"
							set FWHMatImax "null"
							if [json exists $scene detector noise snr_at_imax value] {
								set SNRatImax [json get $scene detector noise snr_at_imax value]
							}
							if [json exists $scene detector noise fwhm_at_imax value] {
								set FWHMatImax [json get $scene detector noise fwhm_at_imax value]
							}

							showInfo "Calculating detector characteristics..."

							set detector [generateDetector $detectorName $detectorType $detPixelSizeU $detPixelSizeV $pixelCountU $pixelCountV $scintillatorMaterialID $scintillatorThickness $minEnergy $maxEnergy $current $integrationTime $nFrames $frontPanelFilters $SDDbrightestSpot $SRb $SNRatImax $FWHMatImax $maxGVfromDetector $GVatMin $GVatMax $GVfactor $GVoffset]

							# Set frame averaging:
							set nFramesToAverage [::ctsimu::get_value $scene {acquisition frame_average}]
							if {![value_is_null_or_zero $nFramesToAverage]} {
								set ::Xdetector(NrOfFrames) $nFramesToAverage
							}

							set nDarkFields [::ctsimu::get_value $scene {acquisition dark_field number} ]
							if {![value_is_null_or_zero $nDarkFields]} {
								set dfIdeal [from_bool [::ctsimu::get_value $scene {acquisition dark_field ideal} ]]
								if { $dfIdeal == 1 } {
									dict set ctsimuSettings takeDarkField 1
								} else {
									fail "aRTist does not support non-ideal dark field images."
								}
							}

							set nFlatFields [::ctsimu::get_value $scene {acquisition flat_field number} ]
							if {![value_is_null_or_zero $nFlatFields]} {
								dict set ctsimuSettings nFlatFrames $nFlatFields

								set nFlatAvg [::ctsimu::get_value $scene {acquisition flat_field frame_average} ]
								if {![value_is_null_or_zero $nFlatAvg]} {
									if {$nFlatAvg > 0} {
										dict set ctsimuSettings nFlatAvg $nFlatAvg 
									} else {
										fail "Number of flat field frames to average must be greater than 0."
									}
								} else {
									fail "Number of flat field frames to average must be greater than 0."
								}

								set ffIdeal [from_bool [::ctsimu::get_value $scene {acquisition flat_field ideal} ]]
								if {![value_is_null_or_zero $ffIdeal]} {
									dict set ctsimuSettings ffIdeal $ffIdeal
								} else {
									dict set ctsimuSettings ffIdeal 0
								}

							} else {
								dict set ctsimuSettings nFlatFrames 0
								dict set ctsimuSettings nFlatAvg 1
								dict set ctsimuSettings ffIdeal 0
							}

							dict set ctsimuSettings startProjNr 0

							# Save and load detector:
							set detectorFilePath [::TempFile::mktmp .aRTdet]
							XDetector::write_aRTdet $detectorFilePath $detector
							Preferences::Set lastopen detectordir [file dirname $detectorFilePath]
							FileIO::OpenAnyGUI $detectorFilePath


							# Drift files.
							if {[json exists $scene drift]} {
								if {![json isnull $scene drift]} {

									# Detector drift:
									if {[json exists $scene drift detector]} {
										if {![json isnull $scene drift detector]} {
											set detectorDriftFile [json get $scene drift detector]
											
										}
									}
								}
							}

							createCERA_RDabcuv
							$ctsimu_scenario set_json_load_status 1; # loaded successfully
							
							return 1

						} else {
							fail "File format version number $version_major.$version_minor is not supported."
						}

					} else {
						fail { "Scenario file does not contain any valid file format version number." }
					}
				} else {
					fail { "This does not appear to be a CTSimU scenario file. Did you mistakenly open a metadata file?" }
				}
			} else {
				fail { "This does not appear to be a CTSimU scenario file. Did you mistakenly open a metadata file?" }
			}

			return 0
		}
	}
}