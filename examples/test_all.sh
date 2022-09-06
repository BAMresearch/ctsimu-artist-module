#!/bin/bash
for i in *.tcl; do
	[ -f "$i" ] || break
	tclsh "$i"
done