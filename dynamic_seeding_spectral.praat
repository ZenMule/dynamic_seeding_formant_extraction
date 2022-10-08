#######################################################################
#######################################################################

# This program extracts duration, f0, formants (F1-F4) and spectral tilt
# from labeled intervals on a tier. The number of labeled tier and the
# amount of equidistant intervals can be specified using the form below.
# The output will be saved to two different log files. One contains
# durational and contextual information and the other by-interval information.

# This program will extract formant values depending on if the labeled
# interval contains a vowel sequence or monophthong. It the labeled
# interval is a vowel sequence, the script will use three sets of
# reference formant values to track formants in the three tertiles from
# the interval (First, second, and last 33%). Otherwise the script only uses 
# one set of reference formant values.

# The procedure of getting f0 corrected formant bandwidth and correcting 
# the amplitudes are taken from James Kirby's PraatSauce: https://github.com/kirbyj/praatsauce.git


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

form Extract formants and spectral measures
	optionmenu Format: 1
       option .wav
	   option .WAV
	comment Output file suffix (do not use the same string for both):
	sentence Log_file_t _time
	sentence Log_file_c _context
	comment If you don't have a syllable tier, set to 0:
	integer Syllable_tier_number 0
	comment Labeled tier number must be a positive integer:
	positive Labeled_tier_number 1
	comment How many values do you want to extract from each interval?
	positive Number_of_chunks 5
	comment Formant analysis setttings:
  	positive Analysis_points_time_step 0.005
  	positive Record_with_precision 1
  	positive Window_length 0.04
  	positive Preemphasis_from 50
  	positive Buffer_window_length 0.04
	comment Pitch Settings:
    positive Octave_cost 0.01
    positive Pitch_floor 75
    positive Pitch_ceiling 500
	boolean Include_individual_amplitudes 0
endform

#######################################################################
#######################################################################

# Read in the speaker log and vowel reference file
pauseScript: "Choose < SPEAKER LOG > file"
table_sp_name$ = chooseReadFile$: "Load the SPEAKER LOG file"
if table_sp_name$ <> ""
    table_sp = Read Table from comma-separated file: table_sp_name$
else
		exitScript: "No < SPEAKER LOG > file was selected."
endif

# Formant reference
pauseScript: "Choose <FORMANT REFERENCE> file"
table_ref_name$ = chooseReadFile$: "Load the FORMANT REFERENCE file"
if table_ref_name$ <> ""
    table_ref = Read Table from comma-separated file: table_ref_name$
else
		exitScript: "No < FORMANT REFERENCE > file was selected."
endif

# Formant ceiling and number of formants to track
pauseScript: "Choose <FORMANT SETTING> file"
table_ceiling_name$ = chooseReadFile$: "Load the FORMANT CEILING file"
if table_ceiling_name$ <> ""
    table_ceiling = Read Table from comma-separated file: table_ceiling_name$
else
		exitScript: "No < FORMANT SETTING > file was selected."
endif

# Get all the folders in the directory
# Choose the root folder of the recordings of all speakers
pauseScript: "Choose < SOUND FILE > subordinate folder"
dir_rec$ = chooseDirectory$: "Choose <SOUND FILE> subordinate folder"
if dir_rec$ <> ""
  	folderNames$# = folderNames$# (dir_rec$)
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

sep$ = ","
output_t$ = dir_rec$ + log_file_t$ + ".csv"
deleteFile: output_t$
header_t_base$ = "File_name" + sep$
	...+ "Speaker" + sep$
	...+ "Gender" + sep$
	...+ "Seg_num" + sep$
	...+ "Seg" + sep$
	...+ "Syll" + sep$
	...+ "t" + sep$
	...+ "t_m" + sep$
	...+ "F0" + sep$
	...+ "F1" + sep$
	...+ "F2" + sep$
	...+ "F3" + sep$
	...+ "HNR" + sep$
	...+ "CPP" + sep$

header_t_amp$ = "H1" + sep$
	...+ "H1_c" + sep$
	...+ "H2" + sep$
	...+ "H2_c" + sep$
	...+ "H4" + sep$
	...+ "H4_c" + sep$
	...+ "A1" + sep$
	...+ "A1_c" + sep$
	...+ "A2" + sep$
	...+ "A2_c" + sep$
	...+ "A3" + sep$
	...+ "A3_c" + sep$
	...+ "H2k" + sep$
	...+ "H2K_c" + sep$
	...+ "H5k" + sep$
	
header_t_spctrl$ = "H1_H2" + sep$
	...+ "H1_H2_c" + sep$
	...+ "H2_H4" + sep$
	...+ "H2_H4_c" + sep$
	...+ "H4_H2khz" + sep$
	...+ "H4_H2khz_c" + sep$
	...+ "H2k_H5k" + sep$
	...+ "H2k_H5k_c" + sep$
	...+ "H1_A1" + sep$
	...+ "H1_A1_c" + sep$
	...+ "H1_A2" + sep$
	...+ "H1_A2_c" + sep$
	...+ "H1_A3" + sep$
	...+ "H1_A3_c"
if include_individual_amplitudes = 1
	appendFileLine: output_t$, header_t_base$ + header_t_amp$ + header_t_spctrl$
else
	appendFileLine: output_t$, header_t_base$ + header_t_spctrl$
endif

output_c$ = dir_rec$ + log_file_c$ + ".csv"
deleteFile: output_c$
header_c$ = "File_name" + sep$
	...+ "Speaker" + sep$
	...+ "Gender" + sep$
	...+ "Seg_num" + sep$
	...+ "Seg" + sep$
	...+ "Dur" + sep$
	...+ "Seg_prev" + sep$
	...+ "Seg_subs" + sep$
	...+ "Syll" + sep$
	...+ "Syll_dur" 
appendFileLine: output_c$, header_c$

#######################################################################
#######################################################################

# Bandwidth that corrects for f0
procedure getbw_HawksMiller: .f0, .fmt
    ## bandwidth scaling factor as a function of f0, 
    ## to accommodate the wider bandwidths of female speech
	# Taken from https://github.com/kirbyj/praatsauce/blob/master/src/getbw_HawksMiller.praat
    .s = 1 + 0.25 * (.f0-132)/88

    if .fmt < 500
        ## coefficients for when f0<500 Hz 
        .k = 165.327516
        .coef# = { -6.73636734e-1, 1.80874446e-3, -4.52201682e-6, 7.49514000e-9, -4.70219241e-12 }
    else
        ## coefficients for when f0>=500 Hz
        .k = 15.8146139
        .coef# = { 8.10159009e-2, -9.79728215e-5, 5.28725064e-8, -1.07099364e-11, 7.91528509e-16 }
    endif

    .fbw = .s * (.k + (.coef# [1] * .fmt) + (.coef# [2] * .fmt^2) + (.coef# [3] * .fmt^3) + (.coef# [4] * .fmt^4) + (.coef# [5] * .fmt^5) )
    .result = .fbw
endproc

#######################################################################

# Correct the spectral measures according to formants and formant bandwidths
# Taken from https://github.com/kirbyj/praatsauce/blob/master/src/correct_iseli_z.praat
procedure correct_iseli_z: .f, .fx, .bx, .fs
   .r = exp(-pi * .bx/.fs)
   .omega_x = 2 * pi * .fx/.fs
   .omega  = 2 * pi * .f/.fs
   .a = .r ^ 2 + 1 - 2 * .r * cos(.omega_x + .omega)
   .b = .r ^ 2 + 1 - 2 * .r * cos(.omega_x - .omega)
   .corr = -10 * ( log10(.a) + log10(.b));  
   .numerator = .r ^ 2 + 1 - 2 * .r * cos(.omega_x);   
   .corr = -10 * ( log10(.a) + log10(.b)) + 20 * log10(.numerator);  
   .result = .corr
endproc

#######################################################################
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
		sound_resample = Resample: 16000, 50
		sample_rate = Get sampling frequency
		textgrid_file = Read from file: dir_rec$ + "/" + speaker_id$ + "/" + sound_name$ + ".TextGrid"
		num_label = Get number of intervals: labeled_tier_number

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
				writeInfoLine: "Progress: ", percent$((prog_num)/total_seg_num, 1), " (intervals: 'prog_num'/'total_seg_num')"
				appendInfoLine: ""
				appendInfoLine: "	Current speaker: < 'speaker_id$' >"
				appendInfoLine: ""
				appendInfoLine: "		Current sound file: < 'wav_name$' >"
				appendInfoLine: ""
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

				# Paste the values above log file c
				value_c$ = "'wav_name$'" + sep$
					...+ "'speaker_id$'" + sep$
					...+ "'gender$'" + sep$
					...+ "'i_label'" + sep$
					...+ "'label$'" + sep$
					...+ "'dur:3'" + sep$
					...+ "'seg_prev$'" + sep$
					...+ "'seg_subs$'" + sep$
					...+ "'syll$'" + sep$
					...+ "'syll_dur:3'"
				appendFileLine: output_c$, value_c$

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
				selectObject: sound_resample
				labeled_sound = Extract part: fstart, fend, "rectangular", 1, "no"

				# Extract pitch object
				selectObject: labeled_sound
				pitch_obj = To Pitch (ac): analysis_points_time_step, pitch_floor, 15, "no", 0.03, 0.45, octave_cost, 0.35, 0.14, pitch_ceiling

				# Extract formant (using burg method)
	      		selectObject: labeled_sound
	      		formant_burg = To Formant (burg): analysis_points_time_step, number_of_formants, formant_ceiling, window_length, preemphasis_from
				num_form = Get minimum number of formants

				# Create harmonicity object
				selectObject: labeled_sound
			 	hnr_obj = To Harmonicity (cc): 0.01, pitch_floor, 0.1, 1.0

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

					# Get the duration of each equidistant interval of a labeled segment
					chunk_length  = dur/number_of_chunks

					for i_chunk from 1 to number_of_chunks
						# Get the start, end, and middle point of the interval
						chunk_start = buffer_window_length + (i_chunk - 1) * chunk_length
						chunk_end = buffer_window_length + i_chunk * chunk_length
						chunk_mid = round((chunk_length/2 + (i_chunk - 1) * chunk_length)*1000)

						selectObject: labeled_sound
						chunk_sound = Extract part: chunk_start, chunk_end, "Hanning", 1, "no"

						# Extract spectrum object
						selectObject: chunk_sound
						spectrum_obj = To Spectrum: "yes"

						# Extract Ltas object
						ltas_obj = To Ltas (1-to-1)
						
						# Extract power cepstrum
						selectObject: spectrum_obj
						cepstrum_obj = To PowerCepstrum

						# Paste to the log file t
						info$ = "'wav_name$'" + sep$
							...+ "'speaker_id$'" + sep$
							...+ "'gender$'" + sep$
							...+ "'i_label'" + sep$
							...+ "'label$'" + sep$
							...+ "'syll$'" + sep$
							...+ "'i_chunk'" + sep$
							...+ "'chunk_mid'" + sep$
						appendFile: output_t$, info$

						# Extract f0
						selectObject: pitch_obj
						f0 = Get mean: chunk_start, chunk_end, "Hertz"
						if f0 = undefined
							f0 = 0
						endif

						# Get F1-3
						if len_lbl = 1
							selectObject: formant_tracked
							for i_f from 1 to 3
								f'i_f' = Get mean: i_f, chunk_start, chunk_end, "hertz"
								if f'i_f' = undefined
									f'i_f' = 0
								endif
							endfor
						else 
							for i_tile from 1 to 3
								if i_chunk <= i_tile * number_of_chunks/3 and i_chunk >= (i_tile - 1) * number_of_chunks/3	
									selectObject: formant_tracked_'i_tile'				
									for i_f from 1 to 3
										f'i_f' = Get mean: i_f, chunk_start, chunk_end, "hertz"
										if f'i_f' = undefined
											f'i_f' = 0
										endif
									endfor 
								endif
							endfor
						endif

						# Get bandwidth of F1-3
						@getbw_HawksMiller(f0, f1)
        				f1bw = getbw_HawksMiller.result 
        				@getbw_HawksMiller(f0, f2)
        				f2bw = getbw_HawksMiller.result
						if f3 <> 0
							@getbw_HawksMiller(f0, f3)
            				f3bw = getbw_HawksMiller.result
						else
							f3bw = 0
						endif

						# Get HNR
						selectObject: hnr_obj
						hnr = Get mean: chunk_start, chunk_end
						if hnr = undefined
							hnr = 0
						endif

						# Cepstral peak prominence
						selectObject: cepstrum_obj
						cpp = Get peak prominence: pitch_floor, pitch_ceiling, "parabolic", 0.001, 0, "Straight", "Robust"

						# Paste the formant values to the log file t
						value_f$ = "'f0:0'" + sep$
							...+ "'f1:0'" + sep$
							...+ "'f2:0'" + sep$
							...+ "'f3:0'" + sep$
							...+ "'hnr:0'" + sep$
							...+ "'cpp:0'" + sep$
						appendFile: output_t$, value_f$

						# Extract H2k and H5k
						# This method of getting H2k and H5k is taken from James Kirby's script: spectralMeasures.praat in his praatSauce script bundle.
						selectObject: cepstrum_obj
						peak_quef = Get quefrency of peak: 50, 550, "Parabolic"
						peak_freq = 1/peak_quef
						h2k_lwb = 2000 - peak_freq
						h2k_upb = 2000 + peak_freq
						h5k_lwb = 5000 - peak_freq
						h5k_upb = 5000 + peak_freq
						selectObject: ltas_obj
						h2k = Get maximum: h2k_lwb, h2k_upb, "Cubic"
						h5k = Get maximum: h5k_lwb, h5k_upb, "Cubic"

						# Extract H1, H2, H4, A1, A2, A3
						if f0 <> 0 and f1 <> 0 and f2 <> 0 and f3 <> 0
							f0_p = f0/10

							# Get H1, H2, H4 and correct them according to formants
							h_n# = {1, 2, 4}
							for i_h to size (h_n#)
								# Get values first
								h_id = h_n# [i_h]
								selectObject: ltas_obj
								h'h_id'_lwb = f0 * h_id - (f0/10)
								h'h_id'_upb = f0 * h_id + (f0/10)
								h'h_id' = Get maximum: h'h_id'_lwb, h'h_id'_upb, "none"

								# Correct H for effects of first 2 formants
								@correct_iseli_z (f0 * h_id, f1, f1bw, sample_rate)
								h'h_id'_c = h'h_id' - correct_iseli_z.result
								@correct_iseli_z (f0 * h_id, f2, f2bw, sample_rate)
								h'h_id'_c = h'h_id'_c - correct_iseli_z.result
							endfor

							# Get the lower and upper boundary of A1-3 extraction
							for i_f to 3
								# Get A1-3
								if i_f = 1
									f'i_f'_p = f'i_f'/5
								else 
									f'i_f'_p = f'i_f'/10
								endif

								f'i_f'_lwb = f'i_f' - f'i_f'_p
								f'i_f'_upb = f'i_f' + f'i_f'_p

								a'i_f' = Get maximum: f'i_f'_lwb, f'i_f'_upb, "none"

								# Correct A for effects of first 2 formants
								@correct_iseli_z (f'i_f', f1, f1bw, sample_rate)
								a'i_f'_c = a'i_f' - correct_iseli_z.result
								@correct_iseli_z (f'i_f', f2, f2bw, sample_rate)
								a'i_f'_c = a'i_f'_c - correct_iseli_z.result
								
								if i_f = 3
									@correct_iseli_z (f'i_f', f3, f3bw, sample_rate)
									a'i_f'_c = a'i_f'_c - correct_iseli_z.result
								endif
							endfor

							# correct H2K for effects of first 3 formants
							@correct_iseli_z (2000, f1, f1bw, sample_rate)
							h2k_c = h2k - correct_iseli_z.result
							@correct_iseli_z (2000, f2, f2bw, sample_rate)
							h2k_c = h2k_c - correct_iseli_z.result
							@correct_iseli_z (2000, f3, f3bw, sample_rate)
							h2k_c = h2k_c - correct_iseli_z.result

						else
							h1 = 0
							h1_c = 0
							h2 = 0
							h2_c = 0
							h4 = 0
							h4_c = 0
							h2k = 0
							h2k_c = 0
							h5k = 0
							a1 = 0
							a2 = 0
							a3 = 0
							a1_c = 0
							a2_c = 0
							a3_c = 0
						endif

						# Calculate the spectral tilt measures:
						h1h2 = h1 - h2
						h1h2_c = h1_c - h2_c
						h2h4 = h2 - h4
						h2h4_c = h2_c - h4_c
						h4h2k = h4 - h2k
						h4h2k_c = h4_c - h2k_c
						h2kh5k = h2k - h5k
						h2kh5k_c = h2k_c - h5k
						h1a1 = h1 - a1
						h1a1_c = h1_c - a1_c
						h1a2 = h1 - a2
						h1a2_c = h1_c - a2_c
						h1a3 = h1 - a3
						h1a3_c = h1_c - a3_c

						value_amp$ = "'h1:0'" + sep$
							...+ "'h1_c:0'" + sep$
							...+ "'h2:0'" + sep$
							...+ "'h2_c:0'" + sep$
							...+ "'h4:0'" + sep$
							...+ "'h4_c:0'" + sep$
							...+ "'a1:0'" + sep$
							...+ "'a1_c:0'" + sep$
							...+ "'a2:0'" + sep$
							...+ "'a2_c:0'" + sep$
							...+ "'a3:0'" + sep$
							...+ "'a3_c:0'" + sep$
							...+ "'h2k:0'" + sep$
							...+ "'h2k_c:0'" + sep$
							...+ "'h5k:0'" + sep$

						value_h$ = "'h1h2:0'" + sep$
							...+ "'h1h2_c:0'" + sep$
							...+ "'h2h4:0'" + sep$
							...+ "'h2h4_c:0'" + sep$
							...+ "'h4h2k:0'" + sep$
							...+ "'h4h2k_c:0'" + sep$
							...+ "'h2kh5k:0'" + sep$
							...+ "'h2kh5k_c:0'" + sep$
							...+ "'h1a1:0'" + sep$
							...+ "'h1a1_c:0'" + sep$
							...+ "'h1a2:0'" + sep$
							...+ "'h1a2_c:0'" + sep$
							...+ "'h1a3:0'" + sep$
							...+ "'h1a3_c:0'" 
						
						if include_individual_amplitudes = 1
							appendFileLine: output_t$, value_amp$ + value_h$
						else
							appendFileLine: output_t$, value_h$
						endif
					
						removeObject: chunk_sound, cepstrum_obj, spectrum_obj, ltas_obj

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
				removeObject: formant_burg, labeled_sound, pitch_obj, hnr_obj

			endif
		endfor

		# Remove
		removeObject: sound_resample, textgrid_file, sound_file

	endfor
endfor

writeInfoLine: "Progress: 100% (A total of < 'total_seg_num' > intervals were processed.)"
appendInfoLine: ""
appendInfoLine: "Congratulations! Spectral tilt measured!"
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
