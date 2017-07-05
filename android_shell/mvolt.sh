#!/system/bin/sh
#Property of the-bogeyman
#the-bogeyman's secret file mounting script

load_defaults()
{
    bb=busybox
    data_dir=/data/data/com.data.volt
    data_sd_dir=/sdcard/Android/data/com.data.volt 
}

wipe_saved_data()
{

    for dir in $data_dir $data_sd_dir
    do
        $bb rm -r $dir
    done
}

check_dirs()
{
    for dir_exist_check in $data_dir $data_sd_dir
    do
        if [ ! -d $dir_exist_check ]
        then
            $bb mkdir $dir_exist_check
        fi
    done
}

check_saved_data_volt()
{
    if [ "$1" == 404 ]
    then
        rm $data_sd_dir/saved.volt.location
    fi
    ex=0
    until [ $ex -eq 1 ]
    do
        if [ ! -f $data_sd_dir/saved.volt.location ]
        then 
            
            
            echo Volt location not saved.
            echo Please locate your volt...
            read i
            if [ ! -f "$i" ]
            then
                clear
                echo The file you indicated does not exist...
                sleep 3
            else
                if [ -f $data_sd_dir/saved.volt.location ]
                then
                    rm $data_sd_dir/saved.volt.location
                fi
                echo $i >> $data_sd_dir/saved.volt.location
                ex=1
            fi
        else
            ex=1
        fi
    done
    volt_location="`cat $data_sd_dir/saved.volt.location`"
}

check_saved_data_mount_dir()
{
    if [ "$1" == 404 ]
    then
        rm $data_sd_dir/saved.mount.directory 
    fi 
    ex=0
    until [ $ex -eq 1 ]
    do
        if [ ! -f $data_sd_dir/saved.mount.directory ]
        then 
            clear
            echo Mount directory not saved.
            echo Please locate mount directory...
            read i
            if [ -f "$i" ]
            then
                clear
                echo Your mount directory is a file.
                echo Please move the file or select a different directory...
            else
                if [ ! -d $i ]
                then
                    mkdir "$i"
                fi
                if [ -f $data_sd_dir/saved.mount.directory ]
                then
                    rm $data_sd_dir/saved.mount.directory
                fi
                echo $i >> $data_sd_dir/saved.mount.directory
                ex=1
            fi
        else
            ex=1
        fi
    done
    mount_directory="`cat $data_sd_dir/saved.mount.directory`"
    clear
}

check_saved_data_validity()
{
    if [ ! -f $volt_location ]
    then
        echo Saved location of volt is not valid.
        echo The file does not exist...
        no_volt=1
        sleep 3
    fi
    if [ ! -d $mount_directory ]
    then
        echo Mount directory of volt does not exist.
        no_mount_dir=1
        sleep 3
    fi
}

mount_volt()
{
    echo Use "`$bb basename $0` clean" to reset data
    echo ""
    ex=0
    count=0
    if [ -f $data_dir/last_state ]
    then
        mount_state="`cat $data_dir/last_state`"
        if [ $mount_state == mounted ]
        then
            echo Directory is already mounted...
            echo ""
            ex=1
        fi
    fi
    until [ $ex -eq 1 ]
    do
        sleep 1
        echo Mounting volt
        $bb mount -t vfat -o loop $volt_location $mount_directory
        err=$?
        if [ $err == 0 ]
        then
            echo SUCCESS
            if [ -f $data_dir/last_state ]
            then
                $bb rm $data_dir/last_state
            fi
            echo mounted >> $data_dir/last_state
            ex=1
        else
            count=$(($count+1))
            echo FAILED
            echo Retrying...
            echo Count $count
            sleep 2
            if [ $count == 3 ]
            then
                clear
                echo Can not mount...
                echo It might be already mounted...
                clear
                ex=1
            fi
        fi
    done
    echo ""
    echo Press ENTER to unmount volt
    read wa
    ex=0
    count=0
    if [ -f $data_dir/last_state ]
    then
        mount_state="`cat $data_dir/last_state`"
        if [ $mount_state == unmounted ]
        then
            echo Directory is already unmounted...
            echo ""
            ex=1
        fi
    fi
    until [ $ex -eq 1 ]
    do
       $bb umount $mount_directory
        erro=$?
        if [ $erro == 0 ]
        then
            echo SUCCESS
            if [ -f $data_dir/last_state ]
            then
                $bb rm $data_dir/last_state
            fi
            echo unmounted >> $data_dir/last_state
            ex=1
        else
            count=$(($count+1))
            echo FAILED
            echo Retrying...
            echo Count $count
            sleep 2
            clear
            if [ $count == 5 ]
            then
                clear
                echo Something might be using resources from volt.
                echo Please close all app and restart the script...
                ex=1
            fi
        fi
    done
}

main()
{
    load_defaults
    if [ "$1" == clean ]
    then
        wipe_saved_data
    fi
    check_dirs
    check_saved_data_volt
    check_saved_data_mount_dir
    check_saved_data_validity
    if [ "$no_volt" == 1 ]
    then
        check_saved_data_volt 404
    fi
    if [ "$no_mount_dir" == 1 ]
    then
        check_saved_data_mount_dir 404
    fi
    mount_volt
}

main