// MANUAL INPUT SETTINGS

// Set channels to use as reference and DNA (i.e. background) regions
ref_channel = 4;
DNA_channel = 1;	// (set to 0 to use entire selection)

// Set enlargement of reference and DNA regions (in pixels)
ref_enlarge = 1;	// default = 1
DNA_enlarge = 8;	// default = 8


// Check whether measurements are larger than for random areas
// by make additional measurements of shifted reference ROI
shifts = 0;			// set number of shifted measurements (max 2)
px_shift = 8;		// select shift distance



////////////////////////// ******************************** ////////////////////////// ******************************** //////////////////////////

// START AUTOMATED MACRO
ori=getTitle();
cropIM = "_cropped_";
roiManager("reset");
close(cropIM);
run("Duplicate...", "title="+cropIM+" duplicate");


// create ROI of DNA region for background measurement
if (DNA_channel){
	setSlice(DNA_channel);
	setAutoThreshold("Default dark");
	run("Create Selection");
	run("Enlarge...", "enlarge="+DNA_enlarge+" pixel");
}
else	run("Select All");

roiManager("Add");
run("Select None");


// create ROI of reference channel
resetThreshold();
run("Duplicate...", "title=convolve duplicate channels=" + ref_channel);
run("Convolve...", "text1=[-1 -1 -1 -1 -1\n-1 -1 -1 -1 -1\n-1 -1 24 -1 -1\n-1 -1 -1 -1 -1\n-1 -1 -1 -1 -1\n] normalize stack");
setAutoThreshold("Default dark");
run("Create Selection");
run("Enlarge...", "enlarge="+ref_enlarge+" pixel");
roiManager("Add");

// make new ROI of region that is part of both ref & DNA
roiManager("select", newArray(0,1));
roiManager("and");	
roiManager("Add");	

// delete ROI that potentially contained regions outside of DNA
roiManager("deselect");
roiManager("select", 1);
roiManager("delete");
close("convolve");


// exclude reference ROI from DNA ROI
roiManager("select", newArray(0,1));
roiManager("XOR");
roiManager("Update");


// create shifted ROIs
for (i = 0; i < shifts; i++) {
	move = px_shift * pow(-1,i);
	
	roiManager("select", 1);
	getSelectionBounds(x, y, width, height);
	Roi.move(x+move, y+move);
	roiManager("Add");
}


// make measurements
roiManager("deselect");
roiManager("Remove Slice Info");
roiManager("Multi Measure");






