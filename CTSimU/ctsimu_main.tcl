# Main CTSimU module file which takes care of sourcing all other files.
# When using the CTSimU module in your own project,
# only source this file to get the whole package.

package require TclOO
package require fileutil
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_batchmanager.tcl]