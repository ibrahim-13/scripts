@echo off
cls

:start

color 03
if exist res (cd res) else (goto nores)
if exist resume del resume
if exist option (goto main) else (goto noption)

:main
cls
if exist resume del resume

title Index file and Search...

echo  #########################################################
echo ##*******************************************************##
echo ##*                                                     *##
echo ##*    The Ultimate File Index and Searching Program    *##
echo ##*                                                     *##
echo ##*******************************************************##
echo  #########################################################

echo.
echo.
echo               # 1. Index all drives
echo               #
echo               # 2. Find files indexed list
echo               #
echo               # 3. Find in old indexed list
echo               #
echo               # 4. Monitor File activity
echo               #
echo               # 5. Reset everything
echo               #
echo               # 6. About
echo               #
echo               # 7. Exit
echo.
echo.

set cho=

set /p cho="Choose your option   "

echo.

cls

for /f %%q in (option) do (
if %%q==%cho% goto opt%cho%
)

echo.
echo.
echo               You have chosen wrong option or invalid input...
echo.
echo.
pause
cls

goto main

:opt1

title INDEXING...

if exist index.bak del index.bak
if exist index.dll ren index.dll index.bak

for %%a in (Q,W,E,R,T,Y,U,I,O,P,A,S,D,F,G,H,J,K,L,Z,X,C,V,B,N,M) do (
cls
echo.
echo Indexing   %%a:   drive...
if exist %%a: dir /s /b %%a:>>index.dll
cls
)

echo.
echo Indexing is done...
echo.
pause
cls

if exist resume goto resume

goto main

:opt2

cls
if exist resume del resume
echo opt2>>resume
if not exist index.dll goto noindex

title Search

echo.
echo #################
echo #  Search file  #
echo #################
echo.
echo 1. View previous search result
echo 2. Export previous search result
echo 3. Add filter
echo 4. Go back to the main page
echo.
echo.
if not (%filf%)==() echo Filter : %filf%
echo.

set file1=

set /p file1="Input   "

if (%file1%)==() goto opt2

if %file1%==1 goto history
if %file1%==2 goto exportfind
if %file1%==3 goto filterfind
if %file1%==4 goto main
cls

if exist find.bak del /f /q find.bak
if exist find.txt.tmp del /f /q find.txt.tmp
if exist find.txt ren find.txt find.bak

if (%filf%)==() (
find /i "%file1%" index.dll>>find.txt
start %windir%\system32\notepad.exe find.txt
cls
goto opt2
) else (
find /i "%filf%" index.dll>>find.txt.tmp
find /i "%file1%" find.txt.tmp>>find.txt
start %windir%\system32\notepad.exe find.txt
cls
goto opt2
)

:opt3

cls
if exist resume del resume
echo opt3>>resume
if not exist index.bak goto noindexbak

cls

title Search

echo.
echo #################
echo #  Search file  #
echo #################
echo.
echo 1. View search history
echo 2. Export previous search result
echo 3. Add filter
echo 4. Go back to the main page
echo.
echo.
if not (%filfo%)==() echo Filter : %filfo%
echo.

set file2=

set /p file2="Option   "

if (%file2%)==() goto opt3

if %file2%==1 goto historyold
if %file2%==2 goto exportfindold
if %file2%==3 goto filterfindold
if %file2%==4 goto main
cls

if exist findold.bak del /f /q findold.bak
if exist findold.txt.tmp del /f /q findold.txt.tmp
if exist findold.txt ren findold.txt findold.bak

if (%filfo%)==() (
find /i "%file2%" index.bak>>findold.txt
start %windir%\system32\notepad.exe findold.txt
cls
goto opt3
) else (
find /i "%filfo%" index.dll>>findold.txt.tmp
find /i "%file2%" findold.txt.tmp>>findold.txt
start %windir%\system32\notepad.exe findold.txt
cls
goto opt3
)

goto opt3

:opt4

title Monitor File activity
cls

echo.
echo ###########################
echo #  Monitor File activity  #
echo ###########################
echo.
echo 1. List all modified files (TODAY)
echo 2. List all deleted files
echo 3. Go back to the main page
echo.
echo.

set act=

set /p act="Input   "

if (%act%)==() goto opt4

if %act%==1 goto listmod
if %act%==2 goto listdel
if %act%==3 goto main
cls

:opt5

cls

title Clean

echo.
echo *******************
echo **    WARNING    **
echo *******************
echo.
echo This will remove all cache and index data !!!
echo.
pause

if exist *.bak del /f /q *.bak
if exist *.txt del /f /q *.txt
if exist *.dll del /f /q *.dll
if exist *.tmp del /f /q *.tmp
if exist resume del /f /q resume
echo.
echo Cache cleaned...
echo.
pause

goto main

:opt6

cls

title About

echo.
echo ##########################################################
echo ##******************************************************##
echo ##*                                                    *##
echo ##*                      ABOUT                         *##
echo ##*                                                    *##
echo ##******************************************************##
echo ##########################################################
echo.
echo.
echo    Creater      : Ibrahim Khan Arshad
echo.
echo    Date Created         : 2/24/2014  2:35PM (Version 3.0)
echo    Last edited          : 3/16/2014  3:03PM
echo    Current Version      : 3.6.5 (Final_stable)
echo.
echo           Use it on your own risk...(LOL)
echo.
echo.
pause
goto main

:opt7

cls

title Good Bye...

echo.
echo ##########################################################
echo ##******************************************************##
echo ##*                                                    *##
echo ##*      Thank you very much for using it...           *##
echo ##*                                                    *##
echo ##******************************************************##
echo ##########################################################
echo.
pause
exit

:noindex

title INDEX data missing...
cls
echo.
echo.
echo No index file found. You must index files before searching...
echo.
echo Indexing will start now...
echo.
pause
goto opt1

:noindexbak

title INDEX Backup data missing...
cls
echo.
echo.
echo No backup index file found...
echo.
echo Indexing will start now...
echo.
pause
goto opt1

:noindexdel

title INDEX and INDEX Backup data missing...
cls
echo.
echo.
echo No previous index file found...
echo.
echo Indexing will start now...
echo.
pause
goto opt1

:resume
for /f %%w in (resume) do goto %%w

:history

title History
if exist find.bak del /f /q find.bak
if exist find.txt ren find.txt find.bak
cls
echo.
if exist find.bak (start %windir%\system32\notepad.exe find.bak) else (echo No previous Search result found...)
echo.
pause
goto opt2

:historyold

title History
if exist findold.bak del /f /q findold.bak
if exist findold.txt ren findold.txt findold.bak
cls
echo.
if exist findold.bak (start %windir%\system32\notepad.exe findold.bak) else (echo No previous Search result found...)
echo.
pause

goto opt2

:noption

cls

echo 1 >>option
echo 2 >>option
echo 3 >>option
echo 4 >>option
echo 5 >>option
echo 6 >>option
echo 7 >>option

cls

goto main

:nores

md res

goto start

:exportfind

title Export Search result
set expdir="%cd%\find.bak"
cls
echo.
echo ##########################
echo #  Export Search Result  #
echo ##########################
echo.
echo 1. Export to Desktop
echo 2. Export to program directory
echo 3. Go back to search option
echo.

set exp=

set /p exp="   "

if (%exp%)==() goto exportfind

if %exp%==1 (
if exist find.bak (
cls
echo.
copy /y find.bak "%systemdrive%\Users\%username%\Desktop\SearchResult.txt">>nul
if exist "%systemdrive%\Users\%username%\Desktop\SearchResult.txt" (echo Export successfull..) else (echo Sorry, there was an error...)
pause
goto opt2
) else (
echo.
echo No previous search result found...
echo.
pause
goto opt2
)
)
if %exp%==2 (
if exist find.bak (
echo.
cd..
echo.
cls
copy /y %expdir% "SearchResult.txt">>nul
if exist SearchResult.txt (echo Export successfull..) else (echo Sorry, there was an error...)
cd res
pause
goto opt2
) else (
echo.
echo No previous search result found...
echo.
pause
goto opt2
)
)
if %exp%==3 goto opt2
echo.
echo You selected wrong option...
echo.
pause

goto exportfind

:exportfindold

title Export Search result
set expdirold="%cd%\findold.bak"
cls
echo.
echo ##########################
echo #  Export Search Result  #
echo ##########################
echo.
echo 1. Export to Desktop
echo 2. Export to program directory
echo 3. Go back to search option
echo.

set expold="

set /p expold="   "

if (%expold%)==() goto exportfindold

if %expold%==1 (
if exist findold.bak (
cls
echo.
copy /y findold.bak "%systemdrive%\Users\%username%\Desktop\SearchResultOld.txt">>nul
if exist "%systemdrive%\Users\%username%\Desktop\SearchResultOld.txt" (echo Export was successfull..) else (echo Sorry, there was an error...)
pause
goto opt3
) else (
echo.
echo No previous search result found...
echo.
pause
goto opt3
)
)
if %expold%==2 (
if exist findold.bak (
echo.
cd..
echo.
cls
copy /y %expdirold% "SearchResultOld.txt">>nul
echo.
if exist SearchResultOld.txt (echo Export was successfull..) else (echo Sorry, there was an error...)
cd res
pause
goto opt3
) else (
echo.
echo No previous search result found...
echo.
pause
goto opt3
)
)
if %expold%==3 goto opt3
echo.
echo You selected wrong option...
echo.
pause

goto exportfindold

:listmod

title Modified Files...
cls

echo ###########################
echo #   List Modified Files   #
echo ###########################

echo.
echo Listing modified files of today...
echo.

if exist date.txt del /f /q date.txt
if exist date.tmp del /f /q date.tmp
date /t >>date.tmp
for /f "tokens=2,3*" %%t in (date.tmp) do echo %%t >>date.txt
if exist date.tmp del /f /q date.tmp
for /f %%y in (date.txt) do set tdate=%%y

if exist mod.txt del /f /q mod.txt
for %%r in (Q,W,E,R,T,Y,U,I,O,P,A,S,D,F,G,H,J,K,L,Z,X,C,V,B,N,M) do (
cls
if exist %%r: (
echo.
echo Workin on : drive %%r
echo ################## >>mod.txt
echo %%r Drive >>mod.txt
echo ################## >>mod.txt
echo.>>mod.txt
if exist %temp%\cache rd /s /q %temp%\cache
if not exist %temp%\cache md %temp%\cache
xcopy.exe %%r:\ %temp%\cache /e /l /d:%tdate% >>mod.txt
echo.>>mod.txt
echo.>>mod.txt
if exist %temp%\cache rd /s /q %temp%\cache
cls
)
)
cls
start %windir%\system32\notepad.exe mod.txt
pause

goto exportmod

:listdel

cls
if exist resume del resume
echo opt4>>resume
if not exist index.dll (
if not exist index.bak goto noindexdel
)

title Deleted Files...
cls

echo ##########################
echo #   List Deleted Files   #
echo ##########################

echo.
echo Listing deleted from current index and backup index (if exists)...
echo.

if exist del.txt del del.txt /f /q

if exist index.bak (
for /f "tokens=*" %%e in (index.bak) do if not exist %%e echo %%e>>del.txt
)
if exist index.dll (
for /f "tokens=*" %%e in (index.dll) do if not exist %%e echo %%e>>del.txt
)
cls
start %windir%\system32\notepad.exe del.txt
pause

goto exportdel

:exportmod

title Export Result
cls
set expdirmod="%cd%\mod.txt"
echo.
echo.
echo *##############################*
echo #  Export Modified Files List  #
echo *##############################*
echo.
echo 1. Export to Desktop
echo 2. Export to program directory
echo 3. Go back to main page
echo.

set expmod=

set /p expmod="   "

if (%expmod%)==() goto exportmod

if %expmod%==1 (
if exist mod.txt (
cls
echo.
copy /y mod.txt "%systemdrive%\Users\%username%\Desktop\ModifiedList.txt">>nul
if exist "%systemdrive%\Users\%username%\Desktop\ModifiedList.txt" (echo Export was successfull..) else (echo Sorry, there was an error...)
pause
goto main
) else (
echo.
echo No previous search result found...
echo.
pause
goto main
)
)
if %expmod%==2 (
if exist mod.txt (
echo.
cd..
echo.
cls
copy /y %expdirmod% "ModifiedList.txt">>nul
echo.
if exist ModifiedList.txt (echo Export was successfull..) else (echo Sorry, there was an error...)
cd res
pause
goto main
) else (
echo.
echo No previous search result found...
echo.
pause
goto main
)
)
if %expmod%==3 goto main
echo.
echo You selected wrong option...
echo.
pause

goto exportmod

:exportdel

title Export Result
cls
set expdirdel="%cd%\del.txt"
echo.
echo.
echo *#############################*
echo #  Export Deleted Files List  #
echo *#############################*
echo.
echo 1. Export to Desktop
echo 2. Export to program directory
echo 3. Go back to main page
echo.

set expdel=

set /p expdel="   "

if (%expdel%)==() goto exportdel

if %expdel%==1 (
if exist del.txt (
cls
echo.
copy /y del.txt "%systemdrive%\Users\%username%\Desktop\DeletedList.txt">>nul
if exist "%systemdrive%\Users\%username%\Desktop\DeletedList.txt" (echo Export was successfull..) else (echo Sorry, there was an error...)
pause
goto main
) else (
echo.
echo No previous search result found...
echo.
pause
goto main
)
)
if %expdel%==2 (
if exist del.txt (
echo.
cd..
echo.
cls
copy /y %expdirdel% "DeletedList.txt">>nul
echo.
if exist DeletedList.txt (echo Export was successfull..) else (echo Sorry, there was an error...)
cd res
pause
goto main
) else (
echo.
echo No previous search result found...
echo.
pause
goto main
)
)
if %expdel%==3 goto main
echo.
echo You selected wrong option...
echo.
pause

goto exportdel

:filterfind

cls
title Filter
set filf=

echo.
echo ##################
echo #   Add filter   #
echo ##################
echo.
echo Leave it empty(press enter) to remove filter and go back...
echo.

set filf=

set /p filf="Filter   "

if (%filf%)==() (
set filf=
goto opt2
)

if (%filf%)==() (
echo.
cls
echo.
echo No filter set. Going back to previous menu...
echo.
pause
goto opt2
)

goto opt2

:filterfindold

cls
title Filter
set filfo=

echo.
echo ##################
echo #   Add filter   #
echo ##################
echo.
echo Leave it empty(press enter) to remove filter and to go back...
echo.

set filfo=

set /p filfo="Filter   "

if (%filfo%)==() (
set filfo=
goto opt3
)

if (%filfo%)==() (
echo.
cls
echo.
echo No filter set. Going back to previous menu...
echo.
pause
goto opt3
)

goto opt3