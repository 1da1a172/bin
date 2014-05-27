#!/usr/bin/zsh

show_help() {
cat << EOL

usage: kk-ui.sh [options] <ROM flashable zip>
Take <ROM flashable zip> and create a flashable zip that removes Holo Blue

	-d <dir>	Set output directory to <dir>
	-r		Create a reversion zip
	-t		Use a TDRS version of apktool
	-l <file>	Log to <file>
	-v		verbose output
EOL
}

clean_env() { # Remove all the intermediate files
	local i

	for i in `echo $APPLIST`; do # Remove old decompiled directories
		if [ -d $i ] ; then
			rm -rf $i
		fi
	done

	if `find dist -name *.apk`; then # Remove old built apks
		rm `find dist -name *.apk`
	fi

	if `ls *.apk`; then # Remove straggaling apks
		rm *.apk
	fi

	if -e src/$BUILD ; then # Remove extracted apks
		rm -rf src/$BUILD
	fi
}

check_deps() { # Make sure we have everything we need
	#TODO
	if [ ! -d $RESDIR ] ; then # Verify we have the white resources
		echo "Resource directory not found" 1>&2
		return $E_NORES
	fi
}

setup_env() { # Get things ready to build
	local i

	# Extract original .apk files
	mkdir src/$BUILD
	for i in `echo $PRIVAPP`; do
		unzip -jd src/$BUILD $ROMDIR/$ROM system/priv-app/$i.apk
	done
	unzip -jd src/$BUILD $ROMDIR/$ROM system/framework/framework-res.apk
	for i in `echo $SYSAPP`; do
		unzip -jd src/$BUILD $ROMDIR/$ROM system/app/$i.apk
	done

	apktool -t ayysir if src/$BUILD/framework-res.apk
}

decode() {
	if [ -z $1 ] ; then
		echo 'ERROR: No package given to decode.' 1>&2
		return $E_GEN
	fi
	$APKTOOL -t $TAG  d $1
}

build() { # $1=package (string); $2=special build conditions (dialer,gallery)
	local SIG='META-INF/MANIFEST.MF META-INF/CERT.SF META-INF/CERT.RSA AndroidManifest.xml'
	local FILE
	local FILTER="has no default translation"

	if [ -z $1 ] ; then
		echo 'ERROR: No packagae given to build.' 1>&2
		return $E_GEN
	fi

	if [ $2 == "dialer"]; then #TODO find out what acutally is breaking this rather than doing this bit of overkill.
		for i in `ls $1/res/values-*/strings.xml -d`; do
			sed -i '/name="throttle_time_frame_subtext"/ s/text">/text" formatted="false">/' $i
		done
	elif [ $2 == "gallery" ]; then 
		FILE=$1/res/values/styles.xml
		sed -i '/name="TextAppearance.DialogWindowTitle"/ s/Title">/Title" parent="">/' $FILE
	fi

	echo 'Building '$i'.apk' 1>&2
	$APKTOOL -t $TAG b $1 2>&1 | grep -v $FILTER 1>&2
	unzip -od $1/build/apk src/$BUILD/$i.apk $SIG
	$APKTOOL -t $TAG b $1 2>&1 | grep -v $FILTER 1>&2
}

copy_res() {
	local i
	if [ -z $1 ] ; then
		echo 'ERROR: No package given to copy new res files into.' 1>&2
		return $E_GEN
	fi

	for i in `ls $RESDIR/$1/res`; do
		if [ -d $1/res/$i ]; then
			cp -r $RESDIR/$1/res/$i $1/res
		fi
	done
}

remove_holo_blue() {
	if [ -z $1 ] ; then
		echo 'ERROR: No package given to modify' 1>&2
		return $E_GEN
	fi

	decode $1
	copy_res $1
	sedit_$1
	build $1
}

package() { #TODO cleanup
	local i

	#build themed .zip
	for i in `echo $PRIVAPP`; do
		mv $i/dist/$i.apk dist/system/privapp
	done
	mv framework-res/dist/framework-res.apk dist/system/framework
	for i in `echo $SYSAPP`; do
		mv $i/dist/$i.apk dist/system/app
	done
	cp src/Follow_KK_UI.zip dist/${BUILD}_follow-kk-ui.zip
	cd dist
	zip -ur ${BUILD}_follow-kk-ui.zip $OUTDIR
	rm `find system -name *.apk`

	#build reversion .zip
	for i in `echo $PRIVAPP`; do
		 cp ../src/$BUILD/$i.apk system/priv-app
	done
	mv ../src/$BUILD/framework-res.apk system/framework
	for i in `echo $SYSAPP`; do
		cp ../src/$BUILD/$i.apk system/app
	done
	cp ../src/Follow_KK_UI.zip ${BUILD}_revert.zip
	zip -ur ${BUILD}_revert.zip system
	mv ${BUILD}_revert.zip $OUTDIR

	cd ..
}

sedit_Calculator() {
	local FILE=Calculator/res/values/colors.xml
	
	sed -i '/name="history_result_light"/ s/4ba5e2/707070/' $FILE
	sed -i '/name="graph_color"/ s/31b6e7/707070/' $FILE
}

sedit_ParanoidOTA() {
	local FILE=ParanoidOTA/res/values/colors.xml
	sed -i '/name="item_action"/ s/33b5e5/707070/' $FILE
}

sedit_Settings() {
	local FILE

	FILE=Settings/smali/com/android/settings/applications/LinearColorBar.smali
	sed -i '/.prologue/,+1 s/ff6634/333334/' $FILE

	FILE=Settings/smali/com/android/settings/applications/ManageApplications.smali
	sed -i s/1060012/106000b/ $FILE

	FILE=Settings/smali/com/android/settings/applications/AppOpsSummary.smali
	sed -i s/1060012/106000b/ $FILE

	FILE=Settings/res/drawable/data_usage_bar.xml
	sed -i s/c050ade5/c0ffffff/g $FILE

	FILE=Settings/res/layout/data_usage_chart.xml
	sed -i s/holo_blue_light/white/g $FILE
	sed -i s/33b5e5/ffffff/g $FILE

	FILE=Settings/res/values/colors.xml
	sed -i '$ i\
		    <item type="color" name="tab_indicator">@*android:color/white</item>' $FILE
}

sedit_framework-res() {
	local FILE
	local LINE

	FILE=framework-res/res/layout/alert_dialog_holo.xml
	sed -i '/android:id="@id\/titleDividerTop"/ s/holo_blue_light/default_dialog_divider_holo_light/' $FILE
	sed -i '/android:id="@id\/titleDivider"/ s/holo_blue_light/default_dialog_divider_holo_light/' $FILE

	FILE=framework-res/res/layout/immersive_mode_cling.xml
	sed -i '/TextView/ s/textColor="#80000000"/textColor="#80ffffff"/' $FILE

	FILE=framework-res/res/values/colors.xml
	sed -i '$ i\
    <color name="default_dialog_text_holo_dark">@android:color/background_holo_light</color>\
    <color name="default_dialog_text_holo_light">@android:color/background_holo_dark</color>\
    <color name="default_dialog_divider_holo_dark">@android:color/background_holo_light</color>\
    <color name="default_dialog_divider_holo_light">#ffacacac</color>' $FILE
	sed -i '/holo_blue_light/ s/33b5e5/dbdbdb/' $FILE
	sed -i '/highlighted_text_holo_dark/ s/33b5e5/ffffff/' $FILE
	sed -i '/highlighted_text_holo_light/ s/33b5e5/000000/' $FILE

	FILE=framework-res/res/values/styles.xml
	sed -i '/name="TextAppearance.Holo.DialogWindowTitle"/,/textColor/ s/holo_blue_light/default_dialog_text_holo_dark/' $FILE
	sed -i '/name="TextAppearance.Holo.Light.DialogWindowTitle"/,/textColor/ s/holo_blue_light/default_dialog_text_holo_light/' $FILE
	sed -i '/name="Widget.Holo.Light.ProgressBar.Horizontal"/ s/Holo.ProgressBar/ProgressBar/' $FILE
	sed -i '/name="Widget.Holo.Light.ProgressBar.Horizontal"/ a\
        <item name="maxHeight">16.0dip</item>\
        <item name="indeterminateDrawable">@drawable/progress_indeterminate_horizontal_holo_light</item>' $FILE
	sed -i '/name="Widget.Holo.Light.ProgressBar.Horizontal"/,/<\/style>/ s/<\/style>/    <item name="minHeight">16.0dip<\/item>\
    <\/style>/' $FILE
	sed -i '/name="Widget.Holo.Light.SeekBar"/,/<\/style>/ s/<\/style>/    <item name="android:thumb">@android:drawable\/scrubber_control_selector_holo_light<\/item>\
    <\/style>/' $FILE
	sed -i '/name="Widget.Holo.Light.TabWidget"/ s/ \/>/>/' $FILE
	sed -i '/name="Widget.Holo.Light.TabWidget"/ a\
        <item name="divider">?dividerVertical</item>\
        <item name="tabStripLeft">@null</item>\
        <item name="tabStripRight">@null</item>\
        <item name="tabStripEnabled">false</item>\
        <item name="measureWithLargestChild">true</item>\
        <item name="showDividers">middle</item>\
        <item name="dividerPadding">8.0dip</item>\
        <item name="tabLayout">@layout/tab_indicator_holo</item>\
    </style>' $FILE
	LINE=`sed -n '/name="Widget.Holo.Light.Tab"/=' $FILE`
	sed -i '/name="Widget.Holo.Light.Tab"/,/<\/style>/ d' $FILE
	sed -i $LINE' i\    <style name="Widget.Holo.Light.Tab" parent="@style\/Widget.Holo.Tab" \/>' $FILE
	sed -i '/name="Widget.Holo.Tab"/,/background/ s/@drawable\/tab_indicator_holo/?tabIndicatorHolo/' $FILE
	sed -i '/name="Theme.Holo"/ a\
        <item name="tabIndicatorHolo">@drawable/tab_indicator_holo</item>' $FILE
	sed -i '/name="Theme.Holo.Light"/ a\
        <item name="tabIndicatorHolo">@drawable/tab_indicator_holo_light</item>' $FILE
	sed -i '/name="Theme.Holo.Light.DarkActionBar"/ a\
        <item name="tabIndicatorHolo">@drawable/tab_indicator_holo_light</item>' $FILE
	sed -i '/name="Widget.Holo.Light.ActionBar.TabView"/ s/Holo.ActionBar.TabView" \/>/ActionBar.TabView">/' $FILE
	sed -i '/name="Widget.Holo.Light.ActionBar.TabView"/ a\
        <item name="background">@drawable/tab_indicator_ab_holo_light</item>\
        <item name="paddingStart">16.0dip</item>\
        <item name="paddingEnd">16.0dip</item>\
    </style>' $FILE
	FILE=framework-res/res/values/attrs.xml
	sed -i '/<resources>/ a\
    <attr name="tabIndicatorHolo" format="reference" />' $FILE

	FILE=framework-res/res/layout/tab_indicator_holo_light.xml
	rm $FILE

	FILE=framework-res/res/values/drawables.xml
	sed -i '/name="notification_template_icon_bg"/ s/3333b5e5/00000000/' $FILE

	FILE=framework-res/res/drawable/scrubber_progress_horizontal_holo_light.xml
	sed -i 's/ry_holo/ry_holo_light/g' $FILE
}

sedit_SystemUI() {
	local FILE=SystemUI/res/layout/status_bar_no_recent_apps.xml
	sed -i 's/holo_blue_light/white/' $FILE
}

sedit_Dialer() {
	local FILE=Dialer/res/values/colors.xml 
	sed -i '/"incall_call_banner_background"/ s/000000</e5e5e5</' $FILE
	sed -i '/"dialpad_background"/ s/000000/e5e5e5/' $FILE
	sed -i '/"incall_secondary_info_background"/ s/33b5e5/e5e5e5/' $FILE
	sed -i '/"incall_call_banner_text_color"/ s/ffffff</404040</' $FILE
	sed -i '/"dtmf_dialer_display_text"/ s/ffffff</404040</' $FILE
	sed -i '/"dialtacts_primary_text_color"/ s/000000/111111/' $FILE
	sed -i '/"dialpad_text_color"/ s/ffffff</404040</' $FILE
	sed -i '/"call_log_voicemail_highlight_color"/ s/33b5e5/404040/' $FILE
	sed -i '/"background_dialer_list_items"/ s/eeeeee/f5f5f5/' $FILE
	sed -i '/"background_dialpad"/ s/#.*</#ffe5e5e5</' $FILE
	sed -i '/"dialpad_primary_text_color"/ s/#.*</#ff404040</' $FILE
	sed -i '/"dialpad_secondary_text_color"/ s/#.*</#ffaaaaaa</' $FILE
	sed -i '/"actionbar_background_color"/ s/ffffff</e6e6e6</' $FILE
	sed -i '/"secondary_text_color"/ s/888888/777777/' $FILE

	FILE=Dialer/res/values/drawables.xml
	sed -i '/name="grayBg"/ s/333333/e5e5e5/' $FILE
}

sedit_Camera2() {
	local PIECOLOR
	local FILE=Camera2/res/values/colors.xml
	sed -i '/name="ingest_highlight_semitransparent"/ s/33b5e5/ffffff/' $FILE
	sed -i '/name="ingest_date_tile_text"/ s/33b5e5/ffffff/' $FILE
	sed -i '/name="review_control_pressed_color"/ s/33b5e5/ffffff/' $FILE
	sed -i '/name="review_control_pressed_fan_color"/ s/33b5e5/ffffff/' $FILE
	sed -i '/name="popup_title_color"/ s/33b5e5/ffffff/' $FILE
	sed -i '/name="mode_selection_border"/ s/33b5e5/ffffff/' $FILE
	sed -i '/name="holo_blue_light"/ s/33b5e5/888888/' $FILE
	sed -i '/name="pano_progress_done"/ s/33525e/888888/' $FILE
	sed -i '/name="pano_progress_indication"/ s/0099cc/ffffff/' $FILE
	sed -i '$ i\
    <color name="pie_selected_paint_color">#88888888</color>' $FILE
	
	build Camera2
	mv Camera2/dist/Camera2.apk .
	decode ./Camera2.apk
	rm ./Camera2.apk
	PIECOLOR=`grep pie_selected_paint_color Camera2/res/values/public.xml | cut -f6 -d'"'`
	FILE=Camera2/smali/com/android/camera/ui/PieRenderer.smali
	sed -i '/.line 198/,+14 d' $FILE
	sed -i '/.line 199/ i\
    .line 198\
    iget-object v1, p0, Lcom/android/camera/ui/PieRenderer;->mSelectedPaint:Landroid/graphics/Paint;\
\
    const v2, '$PIECOLOR'\
\
    invoke-virtual {v0, v2}, Landroid/content/res/Resources;->getColor(I)I\
\
    move-result v2\
\
    invoke-virtual {v1, v2}, Landroid/graphics/Paint;->setColor(I)V\
' $FILE

	FILE=Camera2/res/values/styles.xml
	sed -i '/name="TextAppearance.DialogWindowTitle"/ s/Title">/Title" parent="">/' $FILE
}

sedit_Mms() {
	local FILE=Mms/res/values/colors.xml
	sed -i '/s/33b5e5/404040/g' $FILE
}

# Definitions
BASEDIR=~/apktool
ROMDIR=~/Dropbox/android/d2vzw/ROMs
ROM=pa_d2lte-4.3-BETA6-ayysir-20140523.zip
OUTDIR=~/Dropbox/android/d2vzw/kk-theme
BUILD=pa-4.3b6-ayysir-20140523
RESDIR=src/resources
PRIVAPP='Dialer Mms Settings SystemUI TeleService ParanoidOTA'
SYSAPP='Browser Calculator Camera2 DeskClock Gallery2'
APPLIST=$PRIVAPP\ framework-res\ $SYSAPP
TAG=ayysir
APKTOOL=apktool
E_NORES=10 # Res files not found
E_GEN=74 # General error (probably a fault in script)

check_deps
clean_env
setup_env

for APP in `echo $APPLIST`; do
	remove_holo_blue $APP
done
package
echo 'Dropbox link:\nhttps://www.dropbox.com/sh/3azn7pw2vkcrhan/URyQaVww7v'
