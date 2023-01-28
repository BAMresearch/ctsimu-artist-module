package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_helpers.tcl]

namespace eval ::ctsimu {
	set valid_endians [list "little" "big"]
	set valid_datatypes [list "float32" "float64" "uint8" "int8" "uint16" "int16" "uint32" "int32"]

	::oo::class create image {
		variable _fname;  # file name

		# For raw images:
		variable _datatype
		variable _width
		variable _height
		variable _depth
		variable _endian
		variable _headersize

		constructor { fname { width 0 } { height 0 } { depth 1 } { datatype "float32" } { endian "little" } { headersize 0 } } {
			my set_filename $fname
			my set_width  $width
			my set_height $height
			my set_depth  $depth
			my set_datatype $datatype
			my set_endian $endian
			my set_headersize $headersize
		}

		destructor {

		}

		# Getters
		# -------------------------
		method filename { } {
			return $_fname
		}

		method datatype { } {
			return $_datatype
		}

		method width { } {
			return $_width
		}

		method height { } {
			return $_height
		}

		method depth { } {
			return $_depth
		}

		method endian { } {
			return $_endian
		}

		method headersize { } {
			return $_headersize
		}

		# Setters
		# -------------------------
		method set_filename { fname } {
			set _fname $fname
		}

		method set_datatype { datatype } {
			if { [::ctsimu::is_valid $datatype $::ctsimu::valid_datatypes] } {
				set _datatype $datatype
			} else {
				::ctsimu::fail "Not a valid image datatype: $datatype. Should be one of: $::ctsimu::valid_datatypes"
			}
		}

		method set_width { width } {
			set _width [expr int($width)]
		}

		method set_height { height } {
			set _height [expr int($height)]
		}

		method set_depth { depth } {
			if { $depth > 0 } {
				set _depth [expr int($depth)]
			} else {
				set _depth 1
			}
		}

		method set_endian { endian } {
			if { [::ctsimu::is_valid $endian $::ctsimu::valid_endians] } {
				set _endian $endian
			} else {
				::ctsimu::fail "Not a valid endianness: $endian. Should be one of: $::ctsimu::valid_endians"
			}
		}

		method set_headersize { headersize } {
			set _headersize [expr int($headersize)]
		}

		# Loader
		# -------------------------
		method load_image { } {
			if { [::ctsimu::aRTist_available] } {
				set fname [my filename]
				if { ![file exists $fname] } {
					::ctsimu::fail "Image file not found: $fname"
					return
				}

				set ext [file extension $fname]

				switch -nocase -- $ext {
					.raw  { return [my load_raw] }
					default { return [::Image::LoadFile $fname] }
				}
			}

			return 0
		}

		method load_raw { } {
			set fname [my filename]

			set endianness "little-endian"
			if { [my endian] == "big" } {
				set endianness "big-endian"
			}

			set type   [my datatype]
			set width  [my width]
			set height [my height]
			set depth  [my depth]

			if { ($width <= 0) || ($height <=0) } {
				::ctsimu::fail "Unable to load image. No valid size given for raw image file: $fname"
				return 0
			}

			set headersize [my headersize]

			if { [::ctsimu::aRTist_available] } {
				return [::Image::LoadRawFile $fname $type $width $height $headersize $endianness $depth ]
			}

			return 0
		}
	}
}