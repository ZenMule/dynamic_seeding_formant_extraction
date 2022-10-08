#################################################################################
#################################################################################
#																				#
# This program extracts duration, formants (F1-F3) and spectral moments			#
# from labeled intervals on a tier, as well as the duration of the syllable,	#
# the word, and the label of the preceding and following labels. The number 	#
# of labeled tier and the amount of equidistant intervals can be specified 		#
# using the form below.															#
#																				#
# The script iterates between a range of ceiling frequency values to extract	# 
# formant values (F1-F3) from each time points. Then the script does time		#
# point-wise optimization by removing 0s and outliers that are 2 standard		#
# deviations away from the mean. After trimming off 0s and outliers, then		#
# the median value of each formant at each time point will be saved.			#
#																				#
# The optimization process is inspired by Christopher Carignan's optimization	#
# script: https://github.com/ChristopherCarignan/formant-optimization.git.		#
#																				#
# Read the README file carefully on how to use this script. 					#
#																				#
# This script is very time consuming if you have a lot of data due to the		#
# optimization process. I have another script that is less accurate but much	#
# faster: https://github.com/ZenMule/DynamicSeedingFormant.git.					#
#																				#
# Please choose to use either one according to your needs.						#
#																				#
#################################################################################
#																				#
# Copyright (c) 2022 Miao Zhang													#
#																				#
# This program is free software: you can redistribute it and/or modify			#
# it under the terms of the GNU General Public License as published by			#
# the Free Software Foundation, either version 3 of the License, or				#
# (at your option) any later version.											#
#																				#
# This program is distributed in the hope that it will be useful,				#
# but WITHOUT ANY WARRANTY; without even the implied warranty of				#
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the					#
# GNU General Public License for more details.									#
#																				#
# You should have received a copy of the GNU General Public License				#
# along with this program. If not, see <https://www.gnu.org/licenses/>.			#
#																				#
#################################################################################
#################################################################################

clearinfo

#################################################################################
#################################################################################

form Extract Formant Values
	optionmenu Format: 1
       option .wav
	   option .WAV
	comment Output file suffix:
	sentence Log_file_t _time
	sentence Log_file_c _context
	comment If you don't have a syllable/word tier, set to 0:
	integer Word_tier_number 0
	integer Syllable_tier_number 0
	comment Labeled tier number must be a positive integer:
	positive Labeled_tier_number 1
	comment How many values do you want to extract per interval?
	positive Number_of_chunks 20
	comment Formant iteration setttings:
	positive Lower_ceiling 3000
	positive Upper_ceiling 6000
	positive Ceiling_increment 50
	comment Formant analysis settings:
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
else
	exitScript: "No < SPEAKER LOG > file was selected."
endif

# Formant reference
pauseScript: "Choose < FORMANT REFERENCE > file"
table_ref_name$ = chooseReadFile$: "Please choose the < FORMANT REFERENCE > file"
if table_ref_name$ <> ""
    table_ref = Read Table from comma-separated file: table_ref_name$
else
	exitScript: "No < FORMANT REFERENCE > file was selected."
endif

# Get all the folders in the directory
# Choose the root folder of the recordings of all speakers
pauseScript: "Choose the < SOUND FILE > folder that contains subfolders"
dir_rec$ = chooseDirectory$: "Choose < SOUND FILE > folder"
if dir_rec$ <> ""
  	folderNames$# = folderNames$# (dir_rec$)
else
	exitScript: "No folder was selected."
endif
num_folder = size (folderNames$#)

#######################################################################

# measure run time
stopwatch

# Set reference values for f4 and f5
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
													..."F3"}

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

output_t$ = dir_rec$ + log_file_t$ + ".csv"
output_c$ = dir_rec$ + log_file_c$ + ".csv"

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
	Set numeric value: .row, "t_m", round(chunk_mid_'i_chunk'*1000)
	Set numeric value: .row, "F1", f1_t'i_chunk'
	Set numeric value: .row, "F2", f2_t'i_chunk'
	Set numeric value: .row, "F3", f3_t'i_chunk'
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

  	# Get all the sound files and textgrid files in the current folder
	wavNames$# = fileNames$# (dir_rec$ + "/" + speaker_id$ + "/*" + format$)

  	#######################################################################

  	# Loop through all the files
	for i_file from 1 to size (wavNames$#)
		wav_name$ = wavNames$# [i_file]
		Read from file: dir_rec$ + "/" + speaker_id$ + "/" + wav_name$
		sound_file = selected("Sound")
		sound_name$ = selected$("Sound")
		Read from file: dir_rec$ + "/" + speaker_id$ + "/" + sound_name$ + ".TextGrid"
		textgrid_file = selected("TextGrid")
		num_label = Get number of intervals: labeled_tier_number

    #######################################################################

    # Loop through all the labeled intervals
		for i_label from 1 to num_label
			selectObject: textgrid_file
			label$ = Get label of interval: labeled_tier_number, i_label
			idx = index(targets$#, label$)

			if label$ <> "" and idx <> 0
				prog_num = prog_num + 1
				len_lbl = length (label$)
				writeInfoLine: "Progress: ", percent$((prog_num-1)/total_seg_num, 1), " (intervals: 'prog_num'/'total_seg_num')"
				appendInfoLine: ""
				appendInfoLine: "	Current speaker: < 'speaker_id$' >"
				appendInfoLine: ""
				appendInfoLine: "		Current sound file: < 'wav_name$' >"
				appendInfoLine: ""
				appendInfoLine: "			Current interval < ['i_label'] >: <'label$'>."

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
					syll_num = Get interval at time: syllable_tier_number, (label_start + (label_end - label_start)/2)

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
					word_num = Get interval at time: word_tier_number, (label_start + (label_end - label_start)/2)

					# Get the word duration and the label
					word_start = Get starting point: word_tier_number, word_num
					word_end = Get end point: word_tier_number, word_num
					word_dur = word_end - word_start
					word$ = Get label of interval: word_tier_number, word_num
				else
					# If there is no word tier, the label of the word is NA, and the duration is 0
					word_dur = 0
					word$ = "NA"
				endif

				# Write result to table c:
				@write_tab_c: tab_c

				#######################################################################

				# Get how many steps there are between the lowest and the highest ceiling frequencies
				step_num = ((upper_ceiling - lower_ceiling) div ceiling_increment) + 1
				ceilings# = from_to_by# (lower_ceiling, upper_ceiling, ceiling_increment)

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
			
				for i_f from 1 to 3
					# Create three matrices to save the iterated formant values
					label_mat_f'i_f' = Create simple Matrix: "frmt_val_f'i_f'", step_num, number_of_chunks, "0"
				endfor

				#######################################################################

				## Formant analysis and spectral analysis
	      		# Extract the formant object first
				fstart = label_start - buffer_window_length
				fend = label_end + buffer_window_length
				selectObject: sound_file
				Extract part: fstart, fend, "rectangular", 1, "no"
				extracted = selected("Sound")

	      		# Get the duration of each equidistant interval of a labeled segment
				chunk_length  = dur/number_of_chunks

				# Loop through different steps of ceiling frequency numbers of formant to track to get formant values
				# loop through steps of ceilings
				for i_step from 1 to step_num 
					i_ceiling = ceilings# [i_step]

					if i_ceiling <= 3700
						number_of_formants = 3
					elsif i_ceiling < 5200
						number_of_formants = 4
					else
						number_of_formants = 5
					endif

					selectObject: extracted
					formant_burg = To Formant (burg): analysis_points_time_step, number_of_formants, i_ceiling, window_length, preemphasis_from
					num_form = Get minimum number of formants

					# Set how many formants the script should track
					if num_form >= 2 and num_form <=4
						number_tracks = num_form

						if len_lbl = 1
							selectObject: formant_burg
							Track: number_tracks, f1_ref, f2_ref, f3_ref, f4_ref, f5_ref, 1, 1, 1
							Rename: "tracked_'sound_name$'_'i_label'_'label$'" 
						else
							for i_tile from 1 to 3
								selectObject: formant_burg
								Track: number_tracks, f1_ref_'i_tile', f2_ref_'i_tile', f3_ref_'i_tile', f4_ref, f5_ref, 1, 1, 1
								Rename: "tracked_'sound_name$'_'i_label'_'label$'_'i_tile'" 
							endfor
						endif
					
						for i_chunk from 1 to number_of_chunks
							# Get the start, end, and middle point of the interval
							chunk_start = buffer_window_length + (i_chunk - 1) * chunk_length
							chunk_end = buffer_window_length + i_chunk * chunk_length
							chunk_mid_'i_chunk' = buffer_window_length + chunk_length/2 + (i_chunk - 1) * chunk_length

							if len_lbl = 1
								selectObject: "Formant tracked_'sound_name$'_'i_label'_'label$'"
									for i_f from 1 to 3
										f'i_f' = Get mean: i_f, chunk_start, chunk_end, "hertz"
										if f'i_f' = undefined
											f'i_f' = 0
										endif
									endfor
							else 
								for i_tile from 1 to 3
									if i_chunk < i_tile * number_of_chunks/3 and i_chunk >= (i_tile - 1) * number_of_chunks/3	
										selectObject: "Formant tracked_'sound_name$'_'i_label'_'label$'_'i_tile'"				
										for i_f from 1 to 3
											f'i_f' = Get mean: i_f, chunk_start, chunk_end, "hertz"
											if f'i_f' = undefined
												f'i_f' = 0
											endif
										endfor 
									endif
								endfor
							endif
							
							# Get the formants values from each extracting chunk
							for i_f from 1 to 3
								# Save the extracted value to the matrix
								selectObject: label_mat_f'i_f'
								Set value: i_step, i_chunk, round(f'i_f')
							endfor

						endfor

						# Remove the tracked formant object
						if len_lbl = 1
							removeObject: "Formant tracked_'sound_name$'_'i_label'_'label$'"
						else
							for i_tile from 1 to 3
								removeObject: "Formant tracked_'sound_name$'_'i_label'_'label$'_'i_tile'"
							endfor
						endif
					endif

					# Remove the formant object
					removeObject: formant_burg

				endfor

				#######################################################################

				# Pointwise optimization
				# Remove the outliers of formant values that are two sds away from the mean first,
				# and then take the median value at each time points for each formants
				for i_f to 3
					selectObject: label_mat_f'i_f'

					for i_chunk from 1 to number_of_chunks
						# Get vectors of the formant values at each time points (chunk)
						t'i_chunk'# = Get all values in column: i_chunk

						# Find the number of 0s
						x = 0
						for j from 1 to size (t'i_chunk'#)
							if t'i_chunk'#[j] = 0
								x = x+1
							endif
						endfor

						# Create a new vector to contain no zero values
						t'i_chunk'_nozero# = zero# (size (t'i_chunk'#) - x)

						# Remove 0s
						y = 1
						for k from 1 to size (t'i_chunk'#)
							if not (t'i_chunk'#[k] = 0)
								t'i_chunk'_nozero#[y] =  t'i_chunk'#[k]
								y = y + 1
							endif
						endfor

						# Get the upper and lower cutting value to remove outliers that are 2 sds from the mean
						cut_upr = mean (t'i_chunk'_nozero#) + 2*stdev (t'i_chunk'_nozero#)
						cut_lwr = mean (t'i_chunk'_nozero#) - 2*stdev (t'i_chunk'_nozero#)

						# Find the number of outliers
						z = 0
						for l from 1 to size (t'i_chunk'_nozero#)
							if (t'i_chunk'_nozero#[l] < cut_lwr or t'i_chunk'_nozero#[l] > cut_upr)
								z = z+1
							endif
						endfor
						
						# Create a new vector to contain non outliers
						t'i_chunk'_filter# = zero#(size (t'i_chunk'_nozero#) - z)
						
						# Remove outliers
						n = 1
						for m from 1 to size (t'i_chunk'_nozero#)
							if not (t'i_chunk'_nozero#[m] < cut_lwr or t'i_chunk'_nozero#[m] > cut_upr)
								t'i_chunk'_filter#[n] = t'i_chunk'_nozero#[m]
								n = n+1
							endif
						endfor
						
						# Find the median value
						median_pos = round(size(t'i_chunk'_filter#)/2)
						t'i_chunk'_filter# = sort#(t'i_chunk'_filter#)
						f'i_f'_t'i_chunk' = t'i_chunk'_filter#[median_pos]
					endfor

					# Remove the matrix that saved all formant values at the current timepoint
					removeObject: label_mat_f'i_f'
				
				endfor

				####################################################################

				for i_chunk from 1 to number_of_chunks
					# Write result to table t:
					@write_tab_t: tab_t				
				endfor

				removeObject: extracted

			endif
		endfor

		removeObject: sound_file, textgrid_file

	endfor

endfor

deleteFile: output_t$
deleteFile: output_c$

selectObject: tab_t
Save as comma-separated file: output_t$
selectObject: tab_c
Save as comma-separated file: output_c$

removeObject: tab_t, tab_c, table_ref, table_sp

writeInfoLine: "Progress: 100% (A total of < 'total_seg_num' > intervals were processed.)"
appendInfoLine: ""
appendInfoLine: "Congratulations! Formant extraction and optimization completed!"
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