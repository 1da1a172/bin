#!/usr/bin/zsh

show_help() {
cat << EOL

usage: kk-ui.sh [options] <ROM flashable zip>
Take <ROM flashable zip> and create a flashable zip that removes Holo Blue

	-d <dir>	Set output directory to <dir>
	-r		Create a reversion zip
	-t		Use TDRS version of apktool
	-l <file>	Log to <file>
	-v		verbose output

EOL
}

clean_env() { # Remove all the intermediate files
	local i

	for i in `echo $APPLIST`; do # Remove old decompiled directories
		[ -e $i ] && rm -rf $i
	done

	[ -e dist ] && rm -r dist # It's easier just to delete the whole folder if it is there
	mkdir -p dist/system/{privapp,framework,app} #and recreate the needed structure
	[ "`find . -maxdepth 1 -name \*.apk`" ] && rm *.apk # remove any straggling .apk files (should never be any)
	[ -e src/extracted ] && rm -rf src/extracted # remove old extracted apks
	[ "`find src -maxdepth 1 -name pa_d2lte\*`" ] && rm -rf src/pa_d2lte* # remove extracted zips from old builds (find a better way)
}

check_deps() { # Make sure we have everything we need
	#TODO: add apktool check, posibbly other stuff
	if [ ! -d $RESDIR ] ; then # Verify we have the white resources
		echo "Resource directory not found" 1>&2
		exit $E_NORES
	fi
	if [ ! -e src/Follow_KK_UI.zip ] ; then
		echo "src/Follow_KK_UI.zip not found." 1>&2
		exit $E_NORES #TODO should probably use a different error code
	fi
	if [ -z `command -v zip` ] ; then
		echo "You forgot to install zip."
		if [ -z `command -v pacman` ] ; then
			sudo pacman -S zip
		else
			echo "And I'm not sure how to install it for you."
			exit $E_NORES #TODO definitely should be a different error code
		fi
	fi
}

setup_env() { # Get things ready to build
	local i

	# Extract original .apk files
	mkdir src/extracted
	for i in `echo $PRIVAPP`; do
		unzip -jd src/extracted $ROM system/priv-app/$i.apk 1>&2
	done
	unzip -jd src/extracted $ROM system/framework/framework-res.apk 1>&2
	for i in `echo $SYSAPP`; do
		unzip -jd src/extracted $ROM system/app/$i.apk 1>&2
	done

	# Install the framework. apktool 1.5.3 and 2.0.0-rc1 use different syntax for this
	# TODO do this better. See Comment at var definitions
	if [ "$APKTOOL" = "$APKTOOL_STABLE" ] ; then
		$APKTOOL -t $TAG if src/extracted/framework-res.apk 1>&2
	elif [ "$APKTOOL" = "$APKTOOL_TRDS" ] ; then
		$APKTOOL if src/extracted/framework-res.apk $TAG 1>&2
	else
		echo 'ERROR: Unknown apktool. Cannot install framework.' 1>&2
		return $E_GEN
	fi
}

decode() { # $1=package.akp (include path!)
	if [ -z $1 ] ; then
		echo 'ERROR: No package given to decode.' 1>&2
		return $E_GEN
	fi
	$APKTOOL d -t $TAG $1 1>&2
}

build() { # $1=package (string); $2=special build conditions (dialer,gallery)
	local SIG='META-INF/MANIFEST.MF META-INF/CERT.SF META-INF/CERT.RSA AndroidManifest.xml'
	local FILTER="has no default translation"
	local FILE
	local i

	if [ -z $1 ] ; then
		echo 'ERROR: No packagae given to build.' 1>&2
		return $E_GEN
	fi

	if [[ "$1" == "TeleService" || "$1" == *Dialer* ]] ; then #TODO find out what acutally is breaking this rather than doing this bit of overkill.
		for i in `ls $1/res/values-*/strings.xml -d`; do
			sed -i '/name="throttle_time_frame_subtext"/ s/text">/text" formatted="false">/' $i
		done
	elif [[ "$1" == *Gallery* || "$1" == *Camera* ]] ; then 
		FILE=$1/res/values/styles.xml
		sed -i '/name="TextAppearance.DialogWindowTitle"/ s/Title">/Title" parent="">/' $FILE
	fi

	$APKTOOL -t $TAG b $1 2>&1 | grep -v $FILTER 1>&2
	unzip -od $1/build/apk src/extracted/$1.apk `echo $SIG`
	$APKTOOL -t $TAG b $1 2>&1 | grep -v $FILTER 1>&2
}

recode() { # build and decode in place
	build $1
	E_BUILD_FAIL=$?
	if [ $E_BUILD_FAIL -eq 0 ] ; then
		mv $1/dist/$1.apk /tmp
		rm -r $1
		decode /tmp/$1.apk
		rm /tmp/$1.apk
	else
		return $E_BUILD_FAIL
	fi
}

copy_res() {
	local i
	if [ -z $1 ] ; then
		echo 'ERROR: No package given to copy new res files into.' 1>&2
		return $E_GEN
	fi

	if [ ! -d $RESDIR/$1/res ] ; then
		echo "WARNING: No new resources for $1"
		return $W_NORES
	fi

	for i in `ls $RESDIR/$1/res`; do
		[ -d $1/res/$i ] && cp -r $RESDIR/$1/res/$i $1/res
	done

}

remove_holo_blue() {
	if [ -z $1 ] ; then
		echo 'ERROR: No package given to modify' 1>&2
		return $E_GEN
	fi

	decode src/extracted/$1.apk
	copy_res $1
	type sedit_$1 1>/dev/null && sedit_$1 # Not all apks need edited
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
	zip -ur ${BUILD}_follow-kk-ui.zip system
	mv ${BUILD}_follow-kk-ui.zip $OUTDIR
	rm `find system -name \*.apk`
	cd $BASEDIR

	#build reversion .zip
	for i in `echo $PRIVAPP`; do
		 cp src/extracted/$i.apk dist/system/priv-app
	done
	cp src/extracted/framework-res.apk dist/system/framework
	for i in `echo $SYSAPP`; do
		cp src/extracted/$i.apk dist/system/app
	done
	cp src/Follow_KK_UI.zip dist/${BUILD}_revert.zip
	cd dist
	zip -ur ${BUILD}_revert.zip system
	mv ${BUILD}_revert.zip $OUTDIR
	rm `find system -name \*.apk`
	cd $BASEDIR
}

sedit_Calculator() {
	local FILE
	
	FILE=Calculator/res/values/colors.xml
	sed -i '/name="history_result_light"/ s/4ba5e2/888888/' $FILE
	sed -i '/name="graph_color"/ s/31b6e7/888888/' $FILE
	
	FILE=Calculator/res/values/styles.xml
	sed -i '/name="ClingTitleText"/,/name="android:textColor"/ s/49c0ec/888888/' $FILE
}

sedit_Settings() {
	local FILE
	local OLD; local NEW

	FILE=Settings/smali/com/android/settings/applications/LinearColorBar.smali
	OLD=ff6634; NEW=333334
	grep $OLD $FILE 1>/dev/null && sed -i '/.prologue/,+1 s/$OLD/$NEW/' $FILE || echo "WARNING: Unable to find $OLD in $FILE" 1>&2

	FILE=Settings/smali/com/android/settings/applications/ManageApplications.smali
	OLD=1060012; NEW=10600b
	grep $OLD $FILE 1>/dev/null && sed -i s/$OLD/$NEW/ $FILE || echo "WARNING: Unable to find $OLD in $FILE" 1>&2

	FILE=Settings/smali/com/android/settings/applications/AppOpsSummary.smali
	grep $OLD $FILE 1>/dev/null && sed -i s/$OLD/$NEW/ $FILE || echo "WARNING: Unable to find $OLD in $FILE" 1>&2

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
	grep default_dialog_text_holo_dark $FILE 1>/dev/null || sed -i '$ i\
    <color name="default_dialog_text_holo_dark">@android:color/background_holo_light</color>\
    <color name="default_dialog_text_holo_light">@android:color/background_holo_dark</color>\
    <color name="default_dialog_divider_holo_dark">@android:color/background_holo_light</color>\
    <color name="default_dialog_divider_holo_light">#ffacacac</color>' $FILE # It may end up being necessary to check for each color, and also to make an edit enforcing the right value, if it is already defined
	sed -i '/name="holo_blue_light"/ s/33b5e5/dbdbdb/' $FILE
	sed -i '/name="highlighted_text_holo_dark"/ s/33b5e5/ffffff/' $FILE
	sed -i '/name="highlighted_text_holo_light"/ s/33b5e5/000000/' $FILE
	#Rush25s theme
	sed -i '/name="holo_blue_dark"/ s/0099cc/636363/' $FILE
	sed -i '/name="holo_blue_bright"/ s/00ddff/cccccc/' $FILE
	sed -i '/name="perms_dangerous_/ s/33b5e5/888888/g' $FILE
	sed -i '/name="keyguard_avatar_frame_pressed_color"/ s/33b5e5/888888/' $FILE

	FILE=framework-res/res/values/styles.xml
	sed -i '/name="TextAppearance.Holo.DialogWindowTitle"/,/textColor/ s/holo_blue_light/default_dialog_text_holo_dark/' $FILE
	sed -i '/name="TextAppearance.Holo.Light.DialogWindowTitle"/,/textColor/ s/holo_blue_light/default_dialog_text_holo_light/' $FILE
	sed -i '/name="Widget.Holo.Light.ProgressBar.Horizontal"/ s/Holo.ProgressBar/ProgressBar/' $FILE
	sed -i '/name="Widget.Holo.Light.ProgressBar.Horizontal"/ a\
        <item name="maxHeight">16.0dip</item>\
        <item name="indeterminateDrawable">@drawable/progress_indeterminate_horizontal_holo_light</item>' $FILE
	sed -i '/name="Widget.Holo.Light.ProgressBar.Horizontal"/,/<\/style>/ s/<\/style>/    <item name="minHeight">16.0dip<\/item>\
    <\/style>/' $FILE # Surely, there is a more elegant way of doing this.
	sed -i '/name="Widget.Holo.Light.SeekBar"/,/<\/style>/ s/<\/style>/    <item name="android:thumb">@android:drawable\/scrubber_control_selector_holo_light<\/item>\
    <\/style>/' $FILE # And this.

	# http://forum.xda-developers.com/showpost.php?p=51444245&postcount=475
	sed -i '/name="Widget.Holo.Light.TabWidget"/ s/ \/>/>/' $FILE
	sed -i '/name="Widget.Holo.Light.TabWidget"/ a\
        <item name="divider">?dividerVertical</item>\
        <item name="tabStripLeft">@null</item>\
        <item name="tabStripRight">@null</item>\
        <item name="tabStripEnabled">false</item>\
        <item name="measureWithLargestChild">true</item>\
        <item name="showDividers">middle</item>\
        <item name="dividerPadding">8.0dip</item>\
        <item name="tabLayout">@layout/tab_indicator_holo_light</item>\
    </style>' $FILE
	sed -i '/name="Widget.Holo.Light.Tab"/,/<\/style>/ s/tab_indicator_holo/tab_indicator_holo_light/' $FILE
	sed -i '/name="Widget.Holo.Light.ActionBar.TabView"/ s/ \/>/>/' $FILE
	sed -i '/name="Widget.Holo.Light.ActionBar.TabView"/ a\
        <item name="background">@drawable/tab_indicator_ab_holo_light</item>\
        <item name="paddingStart">16.0dip</item>\
        <item name="paddingEnd">16.0dip</item>\
    </style>' $FILE

	# http://forum.xda-developers.com/showpost.php?p=52502121&postcount=593
	sed -i '/name="Widget.Holo.Light.TabWidget"/,/<\/style>/ s/tab_indicator_holo_light/tab_indicator_holo/' $FILE
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

	FILE=framework-res/res/values/attrs.xml
	sed -i '/<resources>/ a\
    <attr name="tabIndicatorHolo" format="reference" />' $FILE

	FILE=framework-res/res/layout/tab_indicator_holo_light.xml
	[ -e $FILE ] && rm $FILE

	FILE=framework-res/res/values/drawables.xml
	sed -i '/name="notification_template_icon_bg"/ s/3333b5e5/00000000/' $FILE

	FILE=framework-res/res/drawable/scrubber_progress_horizontal_holo_light.xml
	sed -i 's/ry_holo/ry_holo_light/g' $FILE
}

sedit_SystemUI() {
	local FILE=SystemUI/res/layout/status_bar_no_recent_apps.xml
	sed -i 's/holo_blue_light/white/g' $FILE
}

sedit_Dialer() {
	local FILE=Dialer/res/values/colors.xml 
	sed -i '/name="incall_call_banner_background"/ s/000000</e5e5e5</' $FILE
	sed -i '/name="dialpad_background"/ s/000000/e5e5e5/' $FILE
	sed -i '/name="incall_secondary_info_background"/ s/33b5e5/e5e5e5/' $FILE
	sed -i '/name="incall_call_banner_text_color"/ s/ffffff</404040</' $FILE
	sed -i '/name="dtmf_dialer_display_text"/ s/ffffff</404040</' $FILE
	sed -i '/name="dialtacts_primary_text_color"/ s/000000/111111/' $FILE
	sed -i '/name="dialpad_text_color"/ s/ffffff</404040</' $FILE
	sed -i '/name="call_log_voicemail_highlight_color"/ s/33b5e5/404040/' $FILE
	sed -i '/name="background_dialer_list_items"/ s/eeeeee/f5f5f5/' $FILE
	sed -i '/name="background_dialpad"/ s/#.*</#ffe5e5e5</' $FILE
	sed -i '/name="dialpad_primary_text_color"/ s/#.*</#ff404040</' $FILE
	sed -i '/name="dialpad_secondary_text_color"/ s/#.*</#ffaaaaaa</' $FILE
	sed -i '/name="actionbar_background_color"/ s/ffffff</e6e6e6</' $FILE
	sed -i '/name="secondary_text_color"/ s/888888/777777/' $FILE

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
	grep 'name="pie_selected_paint_color"' $FILE || sed -i '$ i\
    <color name="pie_selected_paint_color">#88888888</color>' $FILE
	
	recode ./Camera2
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
	sed -i 's/33b5e5/404040/g' $FILE
}

sedit_Browser() {
	local FILE=Browser/res/values/colors.xml
	sed -i '/name="qc_normal"/ s/e02a96bc/cc888888/' $FILE
	sed -i '/name="qc_selected"/ s/e0ff8800/cc636363/' $FILE
	sed -i '/name="qc_sub"/ s/f01a5b73/cc888888/' $FILE
	sed -i '/name="qc_tab_nr"/ s/f033b5e5/cc636363/' $FILE
	sed -i '/name="navtab_bg"/ s/80606060/ff1c1e20/' $FILE
}

sedit_Email() {
	local FILE

	FILE=Email/res/values/colors.xml
	sed -i '/name="conv_header_text_link_blue"/ s/35b4e3/666666/' $FILE
	sed -i '/name="swipe_to_refresh_text_color"/ s/0099cc/888888/' $FILE
	sed -i '/name="holo_blue_dark"/ s/0099cc/666666/' $FILE
	sed -i '/name="holo_blue_light"/ s/33b5e5/888888/' $FILE
}

# Definitions
OLDDIR=`pwd`
BASEDIR=~/apktool
OUTDIR=~/Dropbox/android/d2vzw/kk-theme
RESDIR=src/resources

PRIVAPP='Mms Settings SystemUI TeleService'
SYSAPP='Browser Calculator Camera2 DeskClock Gallery2'
APPLIST=$PRIVAPP\ framework-res\ $SYSAPP

TAG=unknown

# SRSLY, find a better way to do this. I'm the only one with apktool-trds.
# Everyone else's is apktool with a different version number
APKTOOL_STABLE=apktool
APKTOOL_TRDS=apktool-trds
APKTOOL=$APKTOOL_STABLE

REVERT=false
VERBOSE=false
W_NORES=10
E_NORES=10 # Res files not found
E_GEN=74 # General error (probably a fault in script)
unset ROM
unset BUILD
unset LOGFILE

# Get options
while :
do
	case $1 in
		-d)
			OUTDIR=$2
			#TODO check and adjust for rel/full paths
			shift
			;;
		-h)
			show_help
			exit 0
			;;
		-r)
			REVERT=true
			;;
		-t)
			APKTOOL=$APKTOOL_TRDS
			;;
		-l)
			LOGFILE=$2
			shift
			;;
		-v)
			VERBOSE=true
			;;
		*.zip)
			ROM=$1
			BUILD=`basename ${ROM%.*}`
			TAG=`echo $BUILD | cut -d\- -f4`
			;;
		*) # No more options. Stop while loop.
			if [[ -z "$ROM" ]] ; then
				echo "No ROM file given!"
				show_help
				exit 1
			fi
			break
			;;
	esac
	shift
done

cd $BASEDIR

check_deps
clean_env
setup_env

for APP in `echo $APPLIST`; do
	remove_holo_blue $APP
done
package
echo 'Dropbox link:\nhttp://goo.gl/Rx0iPR'
cd $OLDDIR
