#!/bin/bash
set -e

srcDir="src"
outDir="dist"
tmpDir="tmp"

while read theme fill stroke shadow hand; do
	cursorDir="$outDir/$theme/cursors"
	index="$outDir/$theme/index.theme"

	# Prepare directories
	rm --recursive --force "$tmpDir"
	rm --recursive --force "$cursorDir"
	mkdir --parents "$tmpDir"
	mkdir --parents "$cursorDir"
	printf "[Icon Theme]\nName=${theme//-/ }\nComment=A modest cursor theme\n" > "$index"

	while read name; do
		svg="$srcDir/svg/$name.svg"
		txt="$srcDir/svg/$name.txt"
		cfg="$tmpDir/$name.cfg"
		cursor="$cursorDir/$name"
		printf "$cursor\n"

		# Extract hotspot
		IFS='(,)' read hotX hotY hotHand hotScale hotMove <<< $(\
			xmlstarlet select --template --match '//_:circle[@id="hot"]' \
				--value-of "concat(@cx,',',@cy,',',@class)" "$svg")

		if [ "$hotHand" = "$hand" ]; then
			hotX=$(awk "BEGIN {print $hotX * $hotScale + $hotMove}")
		fi

		# Render png
		for scale in 1 1.5 2 2.5 3 4; do
			size=$(awk "BEGIN {print int($scale * 24 + 0.5)}")
			x=$(awk "BEGIN {print int($scale * $hotX + 0.49)}")
			y=$(awk "BEGIN {print int($scale * $hotY + 0.49)}")

			while read frame delay attrib; do
				png="$tmpDir/$name-$size-$frame.png"
				printf "$size $x $y $png $delay\n" >> "$cfg"
				sed -e "s|#fafbfc|$fill|g" \
					-e "s|#1a1b1c|$stroke|g" \
					-e "s|#0a0b0c|$shadow|g" \
					-e "s|class=\"anim\"|$attrib|g" \
					-e "s|class=\"$hand(\([-0-9]*\),\([-0-9]*\))\"|transform=\"translate(\2)scale(\1,1)\"|g" \
					-e 's|id="hot"|display="none"|g' \
					"$svg" | rsvg-convert --zoom "$scale" --output "$png"
			done < <(cat --number "$txt" 2>/dev/null || printf '1\n')
		done

		# Generate cursor
		xcursorgen "$cfg" "$cursor"

	done < <(grep "^[0-9A-Za-z]" "$srcDir/names.txt")

	# Add alternative names
	while read alias target; do
		ln --symbolic --force "$target" "$cursorDir/$alias"
	done < <(grep "^[0-9A-Za-z]" "$srcDir/aliases.txt")

done < <(grep "^[0-9A-Za-z]" "$srcDir/themes.txt")
