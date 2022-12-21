requires("1.52p");

////// set parameters

kt_marker_channel = 4;		// unused -- channel to recognize kinetochores in
measurement_channel = 2;	// channel to make measurement on

max_sisdist = 10;			// max distance of sister kinetochores (in pixel units)
box_offset = 7;				// size offset for corona around kinetochores (in pixel units)
prominence = 10000;			// adjust up to make kt selection stricter

output_unit = "pixel";		// set to "micron" to get area in square microns rather than pixels (will read pixelsize from metadata)
auto_threshold = 1;			// 0 pauses to allow manual adjustment of corona threshold. use 1 for automatic corona threshold

xy_sigma = 25;				// gaussian blur (in xy) for corona channel
z_sigma = 0;				// gaussian blur (in z) for corona channel


// auto corona thresholding settings
mincellarea = 1e4;
Thresh_1 = "Percentile";
Thresh_2 = "Li";


print("\\Clear");
run("Close All");
activate_crop = 1;		// use crop regions (1) or whole images (0)



crop_box = newArray(115, 10, 265, 365);	// initial box size (adjusted to previous size after each image)

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
// set the following to non-zero to demonstrate how macro works.
// It will pauze a few times to show the individual steps
Therapy = 0;

////// define image series and initiate function
dir = getDirectory("Choose a Directory");
flist = getFileList(dir);

for (f = 0; f < flist.length; f++) {
	file = flist[f];
	if (endsWith(file,"_D3D.dv")) {
		open(dir + File.separator + file);
//		print(file);
		crop_box = coro_area(crop_box);
		
		// SAVE INTERMEDIATE OUTPUT (will update and overwrite after each image)
		selectWindow("Log");
		saveAs("Text", dir+File.separator+"_Corona_Areas_CH"+measurement_channel+"_V4.csv");
		print("");


	}
}



////// the function below actually does the work
function coro_area(crop_box){
	
	roiManager("reset");
	
	////// project and prepare image
	ori = getTitle();
	getDimensions(width, height, channels, slices, frames);
	getPixelSize(unit, pixelWidth, pixelHeight);
	run("Properties...", "channels="+channels+" slices="+slices+" frames="+frames+" unit=px pixel_width=1 pixel_height=1 voxel_depth=1");
	run("Z Project...", "projection=[Max Intensity]");
	prj = getTitle();
	setSlice(kt_marker_channel);

	if(activate_crop){
		makeRectangle(crop_box[0],crop_box[1],crop_box[2],crop_box[3]);
		
		waitForUser("adjust area");
	}
	getSelectionBounds(x, y, width, height);
	crop_box = newArray(x, y, width, height);
	print(ori + ",(" + x + "/" + y + "/" + width + "/" + height + ")" );

	run("Duplicate...", "title=cropped duplicate");
	saveAs("Tiff", dir+File.separator+file+"_projection.tif");
	crop = getTitle();
	
	selectImage(ori);
	makeRectangle(x, y, width, height);
	//run("Crop");

	
	////// find individual kinetochore spots
	selectImage(crop);
	run("Duplicate...", "title=sharpened");
	sharp = getTitle();
	run("Sharpen");	run("Sharpen");
	run("Find Maxima...", "prominence="+prominence+" strict exclude output=List");

	if (Therapy){
		run("Set... ", "zoom=200 x=10 y=10");
		waitForUser("Show 'Find Maxima' function");
	}
	close(sharp);
	

	////// connect potential sisters based on distance and place box around
	////// test all combinations of pairs (probably not the most efficient but it works)
	selectImage(crop);
	for (i = 0; i < nResults; i++) {
		x1 = getResult("X", i);
		y1 = getResult("Y", i);
		for (j = i+1; j < nResults; j++) {
			x2 = getResult("X", j);
			y2 = getResult("Y", j);
	
			xdist = abs(x1-x2);
			ydist = abs(y1-y2);
			dist = sqrt(xdist*xdist + ydist*ydist);
			
			if (dist < max_sisdist){
				x0 = minOf(x1, x2);		xx = maxOf(x1, x2);
				y0 = minOf(y1, y2);		yx = maxOf(y1, y2);
	
				makeLine(x1, y1, x2, y2);
				//angle = getValue("Angle");

				makeRectangle(x0-box_offset, y0-box_offset, xdist+2*box_offset, ydist+2*box_offset);
				roiManager("add");
			}
		}	
	}
	selectImage(crop);
	if (Therapy){
		run("Set... ", "zoom=100 x=10 y=10");
		roiManager("Show All without labels");
		waitForUser("show all boxes");
		selectImage(crop);
	}
	
	
	////// check for non-overlap of boxes and measure size
	
	// create a b/w image of thresholded and bg subtracted coronas to measure size on
	selectImage(ori);
	run("Duplicate...", "title=deblurred duplicate channels="+measurement_channel);
	run("Grays");
	meas_stack = getTitle();
	run("Duplicate...", "title=blur duplicate");
	blurstack = getTitle();
	run("Gaussian Blur 3D...", "x="+xy_sigma+" y="+xy_sigma+" z="+z_sigma);
	imageCalculator("Subtract stack", meas_stack,blurstack);
	run("Z Project...", "projection=[Max Intensity]");
	blurmax = getTitle();
	close(blurstack);
	close(meas_stack);
	selectImage(blurmax);
	
	run("Duplicate...", "title=coromask");
	coromask = getTitle();
	if (Therapy){
		selectImage(prj);
		setSlice(measurement_channel);
		selectImage(coromask);
		waitForUser("deblurred corona image");
		selectImage(coromask);
	}
	setAutoThreshold(Thresh_1+" dark");
	if (Therapy){
		waitForUser("cell threshold");
		selectImage(coromask);
	}
	// alternative is to deblur (s=25) and subtract the max projection again, and use Li threshold. Similar results for 2 images tested
	run("Analyze Particles...", "size="+mincellarea+"-Infinity pixel show=Nothing include add");
	roiManager("Select", roiManager("count")-1);
	getStatistics(area);
	if (area >= mincellarea) run("Enlarge...", "enlarge=-10 pixel");
	else									roiManager("deselect");
	setAutoThreshold(Thresh_2+" dark");
	if (Therapy){
		waitForUser("corona threshold");
		selectImage(coromask);
	}
	else if (!auto_threshold){
		selectImage(blurmax);
		run("Set... ", "zoom=150 x=10 y=10");
		roiManager("Show None");
		roiManager("Deselect");
		makeRectangle(0,0,0,0);
			
		selectImage(coromask);
		run("Set... ", "zoom=150 x=134 y=192");
		roiManager("Show None");
		roiManager("Deselect");
		makeRectangle(0,0,0,0);
		
		waitForUser("adjust corona threshold");
	}
	run("Convert to Mask");
	if (area >= mincellarea){
		roiManager("select", roiManager("count")-1);
		roiManager("delete");
	}
	//run("Analyze Particles...", "size=4-Infinity pixel show=Masks exclude clear");

	
	if (Therapy){
		run("Set... ", "zoom=200 x=10 y=10");
		roiManager("Show None");
		waitForUser("show corona mask");
	}
	
	// create an image to check uniqueness of box
	// white represents pixels uniquely assigned to a single box
	newImage("checker", "8-bit black", width, height, 1);
	checker = getTitle();
	roiManager("Remove Channel Info");

	roiManager("XOR");
	
	run("Invert");
	if (Therapy){
		run("Set... ", "zoom=150 x=10 y=10");
		roiManager("Show All without labels");
		waitForUser("show XOR image");
		selectImage(checker);
	}

	////// test each box text whether it is 100% white
	// (i.e. all pixels uniquely assigned to this pair of kinetochores)
	// delete ROI if no; measure area if yes --> area measurement moved to post quality control
	selectImage(checker);
	for (i = 0; i < roiManager("count"); i++) {
		selectImage(checker);
		roiManager("select", i);
		if (getValue("Mean") < 255) {
			// delete ROIs that have overlap
			roiManager("delete");
			i--;
		}
		// MOVED MEASUREMENTS TO POST QUALITY CONTROL
		else{
			// measure area within ROIs that are non-overlapping
/*			selectImage(coromask);
			roiManager("select", i);
			area = getValue("IntDen")/255;
			print (i+1 + "," + area);	// in px^2
			//print (i+1, area*pixelWidth*pixelHeight);	// converted to um^2
*/
			roiManager("rename", i+1+" (auto-detected)");
		}

	}
	if (Therapy){
		run("Set... ", "zoom=150 x=10 y=10");
		waitForUser("show XOR image with fewer ROIs");
		selectImage(checker);
	}

	////// save ROIs and present for quality control
	selectImage(crop);
	setSlice(kt_marker_channel);
	run("Select None");
	run("Grays");
	run("Duplicate...", "title=kt_marker");
	marker=getTitle();
	selectImage(crop);
	setSlice(measurement_channel);
	run("Select None");
	run("Grays");
	run("Duplicate...", "title=channel_"+measurement_channel);
	measure = getTitle();

//	measure = blurmax;	// is max projection of 3D deblurred measurement channel stack
//controlledcrash

	close(crop);
	close(checker);
	close(ori);
	close(prj);

	oriROIs = roiManager("count");
	preROIs = roiManager("count");
	postROIs = -1;
	loopcount = 0;
	while (preROIs != postROIs) {
		preROIs = roiManager("count");
		disp_qual_contr();

		if (loopcount == 0)		waitForUser("check recognition and delete/add ROIs");
		else					waitForUser("adjusted ROI list ("+loopcount+") displayed\nre-check recognition and delete/add ROIs");
		postROIs = roiManager("count");
		loopcount++;
	}
	

	selectImage(coromask);
	saveAs("Tiff", dir+File.separator+file+"_coronamask.tif");
	if (postROIs > 0){
		for (i = 0; i < roiManager("count"); i++) {
			// measure area within ROIs that are non-overlapping
			roiManager("select", i);
			area = getValue("IntDen")/255;
			roiname = call("ij.plugin.frame.RoiManager.getName", i);

			if (endsWith(roiname,"(auto-detected)"))	suffix = "auto";
			else										suffix = "manual";
			
			if (output_unit == "pixel")			print (i+1 + "," + area + "," + suffix);	// in px^2
			else if (output_unit == "micron")	print (i+1 + "," + area*pixelWidth*pixelHeight + "," + suffix);	// converted to um^2
			else exit("output_unit needs to be set to either pixel or micron");
		}
		roiManager("save", dir+file+"_coronas.zip");
	}
	
	
	run("Close All");
	return crop_box;
}



function disp_qual_contr(){
	for (im=0; im<nImages; im++){
		selectImage(im+1);
		run("Set... ", "zoom=150 x=10 y=10");
		roiManager("show all without labels");
	}
/*
	selectImage(marker);
	roiManager("show all without labels");
	run("Set... ", "zoom=150 x=10 y=10");

	selectImage(blurmax);
	roiManager("show all without labels");
	run("Set... ", "zoom=150 x=10 y=10");
	
	selectImage(coromask);
	run("Set... ", "zoom=150 x=10 y=10");
	roiManager("Show All without labels");

	selectImage(measure);
	roiManager("show all without labels");
	run("Set... ", "zoom=150 x=10 y=10");
*/
	run("Tile");
	selectWindow("ROI Manager");
	for (w = 0; w < roiManager("count"); w++) {
		roiManager("select", w);
		roiname = call("ij.plugin.frame.RoiManager.getName", w);
		if( !endsWith(roiname,"(auto-detected)")){
			roiManager("rename", w+1 + " (manually added)");
		}
		else	roiManager("rename", w+1 + " (auto-detected)");
	}
	roiManager("deselect");
}
