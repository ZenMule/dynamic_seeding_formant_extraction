#######################################################################
#######################################################################

# This program extracts duration, formants (F1-F4) and spectral moments
# from labeled intervals on a tier. The number of labeled tier and the
# amount of equidistant intervals can be specified using the form below.
# The output will be saved to two different log files. One contains
# durational and contextual information and the other formant related
# information.

# This program will extract formant values depending if the labeled
# interval contains a vowel sequence or monophthong. It the labeled
# interval is a vowel sequence, the script will use three sets of
# reference formant values to track formants in the three tertiles from
# the interval. Otherwise the script will only use one set of reference
# formant values.

# Please read the README.md file carefully on how to organize your recordings
# and how to prepare for the reference files. If the preparation is not
# done correctly, the script will not work.

#######################################################################

# Copyright (c) 2021-2022 Miao Zhang

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

#######################################################################
#######################################################################

clearinfo

#######################################################################
#######################################################################

form Extract Formant Values
	optionmenu Format: 1
       option .wav
	   option .WAV
	comment Output file suffix (do not use the same string for both):
	sentence Log_file_t _time
	sentence Log_file_c _context
	comment Labeled tier number must be a positive integer:
	positive Labeled_tier_number 1
	comment If you don't have a syllable/word tier, set to 0:
	integer Word_tier_number 0
	integer Syllable_tier_number 2
	comment How many values do you want to extract from each interval?
	positive Number_of_chunks 20
	comment Formant analysis setttings:
  	positive Analysis_points_time_step 0.005
  	positive Window_length 0.025
  	positive Preemphasis_from 50
  	positive Buffer_window_length 0.04
endform

#######################################################################
#######################################################################

# Read in the speaker log and vowel reference file
pauseScript: "Choose < SPEAKER LOG > file"
table_sp_name$ = chooseReadFile$: "Please choose the < SPEAKER LOG > file"
if table_sp_name$ <> ""
    table_sp = Read Table from comma-separated file: table_sp_name$
	ncol_sp = Get number of columns
	if ncol_sp <> 2
		removeObject: table_sp
		exitScript: "This is not the < SPEAKER LOG > file." + newline$ 
		...+ "Read the README file and make sure your < SPEAKER LOG > file has exactly TWO columns and is formatted correctly."
	endif
else
	exitScript: "No < SPEAKER LOG > file was selected."
endif

# Formant reference
pauseScript: "Choose < FORMANT REFERENCE > file"
table_ref_name$ = chooseReadFile$: "Please choose the < FORMANT REFERENCE > file"
if table_ref_name$ <> ""
    table_ref = Read Table from comma-separated file: table_ref_name$
	ncol_ref = Get number of columns
	if ncol_ref <> 11
		removeObject: table_ref
		exitScript: "This is not the < FORMANT REFERENCE > file." + newline$ 
		...+ "Read the README file and make sure your FORMANT REFERENCE file has ELEVEN columns and is formatted correctly."
	endif
else
	exitScript: "No < FORMANT REFERENCE > file was selected."
endif

# Formant ceiling and number of formants to track
pauseScript: "Choose < FORMANT CEILING > file"
table_ceiling_name$ = chooseReadFile$: "Please choose the < FORMANT CEILING > file"
if table_ceiling_name$ <> ""
    table_ceiling = Read Table from comma-separated file: table_ceiling_name$
	ncol_ceiling = Get number of columns
	if ncol_ceiling <> 3
		removeObject: table_ceiling
		exitScript: "This is not the < FORMANT CEILING > file." + newline$ 
		...+ "Read the README file and make sure your FORMANT REFERENCE file has ELEVEN columns and is formatted correctly."
	endif
else
		exitScript: "No < FORMANT CEILING > file was selected."
endif

# Get all the folders in the directory
# Choose the root folder of the recordings of all speakers
pauseScript: "Choose < SOUND FILE > folder"
dir_rec$ = chooseDirectory$: "Choose <SOUND FILE> subordinate folder"
if dir_rec$ <> ""
  	folderNames$# = folderNames$# (dir_rec$)
	if size (folderName$#) = 0
		exitScript: "There are no subfolders in the directory you just chose."
	endif
else
	exitScript: "No folder was selected."
endif

#######################################################################

# measure run time
stopwatch

f4_ref = 3850
f5_ref = 4950

# Get all target segments from the reference table
selectObject: table_ref
nrow_ref = Get number of rows
v_col$ = Get column label: 1

targets$ = "" 

for i to nrow_ref
	selectObject: table_ref
	i_vowel$ = Get value: i, v_col$
	if index(targets$, i_vowel$) = 0
		if i <> nrow_ref	
			targets$ = targets$ + i_vowel$ + " "
		else
			targets$ = targets$ + i_vowel$
		endif
	endif
endfor

targets$# = splitByWhitespace$# (targets$)

# Create tables to save the result
tab_t = Create Table with column names: "tab_t", 0, {"File_name", 
													..."Speaker", 
													..."Gender", 
													..."Seg_num",
													..."Seg",
													..."Syll",
													..."Word",
													..."t",
													..."t_m",
													..."F1", 
													..."F2", 
													..."F3", 
													..."F4",
													..."COG",
													..."sdev",
													..."skew",
													..."kurt"}

tab_c = Create Table with column names: "tab_c", 0, {"File_name",
													..."Speaker",
													..."Gender",
													..."Seg_num",
													..."Seg",
													..."Dur",
													..."Seg_prev",
													..."Seg_subs",
													..."Syll",
													..."Syll_dur",
													..."Word",
													..."Word_dur"}

# The files that the results will be eventually saved in
output_t$ = dir_rec$ + log_file_t$ + ".csv"
output_c$ = dir_rec$ + log_file_c$ + ".csv"
# Delete existing files
deleteFile: output_t$
deleteFile: output_c$

# The procedures that log the result to the tables
procedure write_tab_t: .table
	selectObject: .table
	Append row
	.row = Get number of rows
	Set string value: .row, "File_name", sound_name$
	Set string value: .row, "Speaker", speaker_id$
	Set string value: .row, "Gender", gender$
	Set numeric value: .row, "Seg_num", i_label
	Set string value: .row, "Seg", label$
	Set string value: .row, "Syll", syll$
	Set string value: .row, "Word", word$
	Set numeric value: .row, "t", i_chunk
	Set numeric value: .row, "t_m", chunk_mid
	Set numeric value: .row, "F1", round(f1)
	Set numeric value: .row, "F2", round(f2)
	Set numeric value: .row, "F3", round(f3)
	Set numeric value: .row, "F4", round(f4)
	Set numeric value: .row, "COG", grav
	Set numeric value: .row, "sdev", sdev
	Set numeric value: .row, "skew", skew
	Set numeric value: .row, "kurt", kurt
endproc

procedure write_tab_c: .table
	selectObject: .table
	Append row
	.row = Get number of rows
	Set string value: .row, "File_name", sound_name$
	Set string value: .row, "Speaker", speaker_id$
	Set string value: .row, "Gender", gender$
	Set numeric value: .row, "Seg_num", i_label
	Set string value: .row, "Seg", label$
	Set numeric value: .row, "Dur", round(dur*1000)
	Set string value: .row, "Seg_prev", seg_prev$
	Set string value: .row, "Seg_subs", seg_subs$
	Set string value: .row, "Syll", syll$
	Set numeric value: .row, "Syll_dur", round(syll_dur*1000)
	Set string value: .row, "Word", word$
	Set numeric value: .row, "Word_dur", round(word_dur*1000)
endproc

#######################################################################

# Get how many intervals there are
total_seg_num = 0

for i_folder from 1 to size (folderNames$#)
	speaker_id$ = folderNames$# [i_folder] 
	wavNames$# = fileNames$# (dir_rec$ + "/" + speaker_id$ + "/*" + format$)
	for i_file from 1 to size (wavNames$#)
		textgrid_name$ = wavNames$# [i_file] - format$
		Read from file: dir_rec$ + "/" + speaker_id$ + "/" + textgrid_name$ + ".TextGrid"
		textgrid_file = selected("TextGrid")
		num_label = Get number of intervals: labeled_tier_number

		for i_label from 1 to num_label
			selectObject: textgrid_file
			label$ = Get label of interval: labeled_tier_number, i_label
			idx = index(targets$#, label$)

			if label$ <> "" and idx <> 0
				total_seg_num = total_seg_num + 1
			endif
		endfor
		removeObject: textgrid_file
	endfor
endfor

prog_num = 0

# Loop through the folders
for i_folder from 1 to size (folderNames$#)
	speaker_id$ = folderNames$# [i_folder] 

	# Get the gender of each speaker from speaker log file
	selectObject: table_sp
	sp_col$ = Get column label: 1
	gender_sp_col$ = Get column label: 2
	gender_row = Search column: sp_col$, speaker_id$
	gender$ = Get value: gender_row, gender_sp_col$

	# Get the formant ceiling and number of formants to track
	selectObject: table_ceiling
	gender_ceiling_col$ = Get column label: 1
	ceiling_col$ = Get column label: 2
	num_form_col$ = Get column label: 3
	gender_ceiling_row = Search column: gender_ceiling_col$, gender$
	formant_ceiling = Get value: gender_ceiling_row, ceiling_col$
	number_of_formants = Get value: gender_ceiling_row, num_form_col$

  	# Get all the sound files and textgrid files in the current folder
	wavNames$# = fileNames$# (dir_rec$ + "/" + speaker_id$ + "/*" + format$)

  	#######################################################################

  	# Loop through all the files
	for i_file from 1 to size (wavNames$#)
		wav_name$ = wavNames$# [i_file]
		sound_file = Read from file: dir_rec$ + "/" + speaker_id$ + "/" + wav_name$
		sound_name$ = selected$("Sound")
		textgrid_file = Read from file: dir_rec$ + "/" + speaker_id$ + "/" + sound_name$ + ".TextGrid"
		num_label = Get number of intervals: labeled_tier_number

		writeInfoLine: "Progress: ", percent$((prog_num)/total_seg_num, 1), " (intervals: 'prog_num'/'total_seg_num')"
		appendInfoLine: ""
		appendInfoLine: "	Current speaker: < 'speaker_id$' >"
		appendInfoLine: ""
		appendInfoLine: "		Current sound file: < 'wav_name$' >"
		appendInfoLine: ""

    	#######################################################################

    	# Loop through all the labeled intervals
		for i_label from 1 to num_label
			selectObject: textgrid_file
			label$ = Get label of interval: labeled_tier_number, i_label
			idx = index(targets$#, label$)
			

      		#######################################################################

			if label$ <> "" and idx <> 0
				len_lbl = length (label$)
				prog_num = prog_num + 1
				appendInfoLine: "			Current interval ['i_label']: <'label$'>."

				# Get the duration of the labeled interval
				label_start = Get starting point: labeled_tier_number, i_label
				label_end = Get end point: labeled_tier_number, i_label
				dur = label_end - label_start

				# Get the label of the previous segment if it is labeled
				seg_prev$ = Get label of interval: labeled_tier_number, (i_label-1)
				if seg_prev$ = ""
					seg_prev$ = "NA"
				endif

				# Get the label of the subsequent segment if it is labeled
				seg_subs$ = Get label of interval: labeled_tier_number, (i_label+1)
				if seg_subs$ = ""
					seg_subs$ = "NA"
				endif

				# Get the lable of the syllable from the syllable tier if there is one
				if syllable_tier_number <> 0
					# Get the index of the current syllable that the labeled segment occurred in
					syll_num = Get interval at time: syllable_tier_number, label_start

					# Get the duration of the syllable
					syll_start = Get starting point: syllable_tier_number, syll_num
					syll_end = Get end point: syllable_tier_number, syll_num
					syll_dur = syll_end - syll_start
					syll$ = Get label of interval: syllable_tier_number, syll_num
				else
					# If there is no syllable tier, the label of syllable is NA, and the duration is 0
					syll_dur = 0
					syll$ = "NA"
				endif

				# Get the label of the word from the word tier if there is one
				if word_tier_number <> 0
					# Get the index of the current word
					word_num = Get interval at time: word_tier_number, label_start

					# Get the word duration
					word_start = Get starting point: word_tier_number, word_num
					word_end = Get end point: word_tier_number, word_num
					word_dur = word_end - word_start
					word$ = Get label of interval: word_tier_number, word_num
				else
					word_dur = 0
					word$ = "NA"
				endif

				# Write result to table c:
				@write_tab_c: tab_c

				#######################################################################

				# Get the reference value of the labeled vowel
				selectObject: table_ref
				# Find the row of the labeled vowel for the current gender
				v_row# = List row numbers where: "self$ [1] = ""'label$'"" and self$ [2] = ""'gender$'"""
				v_row = v_row# [1]

				appendInfoLine: ""
				if len_lbl = 1
					for i_f from 1 to 3
						selectObject: table_ref
						ref_col$ = Get column label: 6 + (i_f-1)
						f'i_f'_ref = Get value: v_row, ref_col$
						appendInfoLine: "				Reference F'i_f': ", f'i_f'_ref
					endfor
				else
					tertiles$# = {"Initial", "Medial", "Final"}
					for i_tile from 1 to 3
						for i_f from 1 to 3
							selectObject: table_ref
							ref_col$ = Get column label: 3 + (i_tile-1)*3 + (i_f-1)
							f'i_f'_ref_'i_tile' = Get value: v_row, ref_col$
							appendInfoLine: "				", tertiles$# [i_tile], " reference F'i_f': ", f'i_f'_ref_'i_tile'
						endfor
						appendInfoLine: ""
					endfor	
				endif

				#######################################################################

				## Formant analysis and spectral analysis
	      		# Extract the formant object first
				fstart = label_start - buffer_window_length
				fend = label_end + buffer_window_length
				selectObject: sound_file
				extracted = Extract part: fstart, fend, "rectangular", 1, "no"

	      		# Get the duration of each equidistant interval of a labeled segment
				chunk_length  = dur/number_of_chunks

	      		selectObject: extracted
	      		formant_burg = To Formant (burg): analysis_points_time_step, number_of_formants, formant_ceiling, window_length, preemphasis_from
				num_form = Get minimum number of formants

	     		# Set how many formants the script should track
	      		if num_form >= 2 and num_form <= 4
	        		number_tracks = num_form

					if len_lbl = 1
						selectObject: formant_burg
						formant_tracked = Track: number_tracks, f1_ref, f2_ref, f3_ref, f4_ref, f5_ref, 1, 1, 1
					else
						for i_tile from 1 to 3
							selectObject: formant_burg
							formant_tracked_'i_tile' = Track: number_tracks, f1_ref_'i_tile', f2_ref_'i_tile', f3_ref_'i_tile', f4_ref, f5_ref, 1, 1, 1
						endfor
					endif

					# Track the formants
					for i_chunk from 1 to number_of_chunks
						# Get the start, end, and middle point of the interval
						chunk_start = buffer_window_length + (i_chunk - 1) * chunk_length
						chunk_end = buffer_window_length + i_chunk * chunk_length
						chunk_mid = round((chunk_length/2 + (i_chunk - 1) * chunk_length)*1000)

						if len_lbl = 1
							selectObject: formant_tracked
							for i_f from 1 to 4
								f'i_f' = Get mean: i_f, chunk_start, chunk_end, "hertz"
								if f'i_f' = undefined
									f'i_f' = 0
								endif
							endfor
						else 
							for i_tile from 1 to 3
								if i_chunk <= i_tile * number_of_chunks/3 and i_chunk >= (i_tile - 1) * number_of_chunks/3	
									selectObject: formant_tracked_'i_tile'				
									for i_f from 1 to 4
										f'i_f' = Get mean: i_f, chunk_start, chunk_end, "hertz"
										if f'i_f' = undefined
											f'i_f' = 0
										endif
									endfor 
								endif
							endfor
						endif

						#######################################################################

						#Getting spectral moments
						selectObject: sound_file
						chunk_part = Extract part: buffer_window_length + (i_chunk - 1) * chunk_length, buffer_window_length + i_chunk * chunk_length, "rectangular", 1, "no"
						spect_part = To Spectrum: "yes"
						grav = Get centre of gravity: 2
						sdev = Get standard deviation: 2
						skew = Get skewness: 2
						kurt = Get kurtosis: 2

						# Write result to table t:
						@write_tab_t: tab_t

						# Remove
						removeObject: chunk_part, spect_part
					endfor

					# Remove the tracked formant object
					if len_lbl = 1
						removeObject: formant_tracked
					else
						for i_tile from 1 to 3
							removeObject: formant_tracked_'i_tile'
						endfor
					endif
				endif
				# Remove
				removeObject: formant_burg, extracted
			endif
		endfor
		# Remove
		removeObject: sound_file, textgrid_file
	endfor
endfor

selectObject: tab_t
Save as comma-separated file: output_t$
selectObject: tab_c
Save as comma-separated file: output_c$

removeObject: table_ceiling, table_ref, table_sp, tab_t, tab_c

writeInfoLine: "Progress: 100% (A total of < 'total_seg_num' > intervals were processed.)"
appendInfoLine: ""
appendInfoLine: "Congratulations! Formant extraction completed!"
appendInfoLine: ""

runtime = stopwatch
runtime = round(runtime)
if runtime < 60
	if runtime < 10
		appendInfoLine: "Total run time is 00:00:0'runtime'"
	else 
		appendInfoLine: "Total run time is 00:00:'runtime'"
	endif
elsif runtime < 3600
	minute = runtime div 60
	second = runtime mod 60
	if minute < 10
		appendInfo: "The total run time is 00:0'minute':"
	else 
		appendInfo: "The total run time is 00:'minute':"
	endif
	if second < 10
		appendInfoLine: "0'second'"
	else 
		appendInfoLine: "'second'"
	endif
else
	hour = runtime div 3600
	rest = runtime mod 3600
	minute = rest div 60
	second = rest mod 60
	if hour < 10
		appendInfo: "The total run time is 0'hour':"
	else
		appendInfo: "The total run time is 'hour':"
	endif
	if minute < 10
		appendInfo: "0'minute':"
	else 
		appendInfo: "'minute':"
	endif
	if second < 10
		appendInfoLine: "0'second'"
	else 
		appendInfoLine: "'second'"
	endif
endif