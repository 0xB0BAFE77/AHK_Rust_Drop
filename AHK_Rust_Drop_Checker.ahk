#SingleInstance Force
#Warn
#NoEnv
rust_dc.Start()
Return

*F1::rust_dc.main.Toggle()
*Escape::ExitApp

~^s::
    IfWinActive, % A_ScriptName
    {
        Run, % A_ScriptFullPath
        Sleep, 1
        ExitApp
    }
Return

/*
error codes
-1 = HTML can't be downloaded
-2 = Error parsing HTML
-3 = Unused
-4 = No streamer HTML to parse
*/

/* To-do:
Create settings gui
Add notification settings:
    * Open up twitch stream page.
    * Pop-up message (it's a regular windows message box).  
    * System beeping (would like to put in the ability for you to use . (dots),  (spaces), and - (dashes) to make neat little beats. But this will come later.)
    * Link to a video/site that has media you want to play. The script will launch that page when the person you want comes on. For example, you'd paste something like this in the box: https://www.youtube.com/watch?v=dQw4w9WgXcQ
    * Flashing notification icon or repeating pop-up/toast notifications.
    * While it's currently not an option, I would like to add a way to send an email and/or text as a notification.
    * Write-to-file. Most won't use this option, but it does allow for an extrenal app to get the current status of streamers and their key info without having to code their own solution.  
    A prime example of use for this would be for live posting to a discord server.
Updater/Version Checker

*/

Class rust_dc
{
    Static  title           := "AHK Rust Drop Checker"
            , version       := "1.0.0"
            , html          := ""
            , err_log       := ""
            , err_last      := ""
            , notify_list   := {}
    
    ; Object tracking
    Static  streamer_data   := [{profile_url      : ""    ; URL to user's twitch or youtube profile (whichever was provided by the site)
                                ,avatar_url       : ""    ; URL to user's gaming avatar
                                ,avatar_loc       : ""    ; Location on disk where avatar is saved
                                ,username         : ""    ; User's username (Redudant, right?)
                                ,online           : 0     ; User's online status
                                ,drop_pic_url     : ""    ; URL picture of this user's Rust drop
                                ,drop_pic_loc     : ""    ; Location on disk where Rust drop picture is saved
                                ,drop_name        : ""    ; The name of the drop
                                ,drop_hours       : 2 }]  ; Watch time need to get drop
    Static  path            := {app                 : A_AppData "\AHK_Rust_Drops"
                               ,img                 : A_AppData "\AHK_Rust_Drops\img"
                               ,temp                : A_AppData "\AHK_Rust_Drops\temp"
                               ,streamers           : A_AppData "\AHK_Rust_Drops\streamers"
                               ,log                 : A_AppData "\AHK_Rust_Drops\log.txt"
                               ,settings            : A_AppData "\AHK_Rust_Drops\settings.ini"
                               ,img_rust_symbol     : A_AppData "\AHK_Rust_Drops\img\img_rust_symbol.png"
                               ,img_rust_symbol_2   : A_AppData "\AHK_Rust_Drops\img\img_rust_symbol_2.png"
                               ,img_online          : A_AppData "\AHK_Rust_Drops\img\img_Online.png"
                               ,img_offline         : A_AppData "\AHK_Rust_Drops\img\img_Offline.png"
                               ,notify_log          : A_AppData "\AHK_Rust_Drops\live_updates.txt"}
    Static  url             := {git_homepage        : "https://github.com/0xB0BAFE77/AHK_Rust_Drop"
                               ,img_online          : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/img/Online%20Blank%203D.png"
                               ,img_offline         : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/img/Offline%20Blank%203D.png"
                               ,img_rust_symbol     : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/img/Rust_Symbol.png"
                               ,img_rust_symbol_2   : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/img/Rust_Symbol_Flash.png"
                               ,git_ver             : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/version.txt"
                               ,ahk_rust_checker    : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/AHK_rust_dc.ahk"
                               ,online_version      : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/version.txt"
                               ,twitch_rewards      : "https://www.twitch.tv/drops/inventory"
                               ,kofi                : "https://ko-fi.com/0xb0bafe77"
                               ,patreon             : "https://www.patreon.com/0xB0BAFE77"
                               ,facepunch           : "https://twitch.facepunch.com/" }
    Static  rgx             := {profile_url         : "<\s*?a\s*?href=""(.*?)"""
                               ,avatar_url          : "img\s+src=""(.*?)""\s+alt="
                               ,username            : "class=""streamer-name"".*?>(.*?)</"
                               ,online              : "online-status.*?>(.*?)<"
                               ,ext                 : "\.(\w+)\s*?$"
                               ,drop_pic_url        : "img\s*?src=""(.*?)"".*?title="
                               ,drop_hrs            : "<span>\s*?(\d+) hours</span>"
                               ,drop_name           : "class=""drop-name"".*?>(.*?)</" }
    Static notify_opt       := [{type               :"stream" , txt:"Open User Stream" , def:False }
                               ,{type               :"popup"  , txt:"Pop-Up Window"    , def:True  }
                               ,{type               :"beep"   , txt:"System Beep"      , def:True  }
                               ,{type               :"icon"   , txt:"Flashing Icon"    , def:True  }
                               ,{type               :"file"   , txt:"Write to File"    , def:False } ]
    Static live_stream      := {active              :False
                               ,username            :""
                               ,pid                 :0
                               ,time                :0}
    ;ghwnd                   := {"notify_stream"     : ""            
    ;                           ,"notify_popup"      : ""
    ;                           ,"notify_beep"       : ""
    ;                           ,"notify_url"        : ""
    ;                           ,"notify_url_edit"   : ""
    ;                           ,"notify_icon"       : ""
    ;                           ,"notify_file"       : ""
    ;                           ,"gui_main"          : ""
    ;                           ,"error_txt"         : ""
    ;                           ,"user.online_pic"   : ""
    ;                           ,"user.online_txt"   : ""
    ;                           ,"user.snooze_btn"   : ""
    ;                           ,"user.dismiss_btn"  : ""
    ;                           ,"user.notify_cb"    : ""
    ;                           ,"updater_gb"        : ""
    ;                           ,"updater_btn"       : ""
    ;                           ,"interval_sld"      : ""
    ;                           ,"cps_txt"           : ""
    ;                           ,"gui_splash"        : ""} 
    
    ; ####################
    ; ##  Startup/Exit  ##
    ; ####################
    Start()
    {
        splash := ObjBindMethod(rust_dc.guis.splash, "update")
        
        rust_dc.guis.splash.start("Starting up`n" this.title)
        
        ; Set shutdown processes
        splash.("Setting`nShutdown`nFunctions")
        OnExit(this._method(this, "shutdown"))
        
        ; Create program folders
        splash.("Creating`nFolders")
        this.folder_check() ? this.error(A_ThisFunc, "Folder's could not be created.", 1) : ""
        
        ; Get fresh streamer data
        splash.("Downloading`nStreamer Data")
        this.get_streamer_data()
        
        ; Create streamer folders
        splash.("Creating`nStreamer`nFolders")
        this.create_streamer_paths() ? this.error(A_ThisFunc, "Unable to create streamer folders.", 1) : ""
        
        ; Load error log
        splash.("Loading`nLog")
        this.load_log() ? this.error(A_ThisFunc, "Unable to load error log.", 1) : ""
        
        ; Download images
        splash.("Downloading`nImages")
        this.download_images() ? this.error(A_ThisFunc, "Unable to download images.", 1) : ""
        
        ; Generate system tray
        splash.("Creating`nFolders")
        this.systray.create() ? this.error(A_ThisFunc, "The system tray could not be created.", 1) : ""
        
        ; Create and load notify_list settings
        splash.("Generating`nNotify List")
        this.generate_notify_list()
        
        ; Create GUI
        splash.("Creating`nGUI")
        this.guis.main.create()
        this.guis.main.Show()
        
        ; Check for updates!
        splash.("Update`nCheck!")
        this.update_check(1)
        ; Update cleanup
        (A_Args.3 = 1) ? this.temp_cleanup() : ""
        
        ; Start heartbeat
        splash.("Starting`nheartbeat.`n(CLEAR!!!)")
        this.heartbeat()
        
        ; Done
        splash.("It's alive!")
        rust_dc.guis.splash.finish()
        Return
    }
    
    load_log()
    {
        status := 0
        If (FileExist(this.path.log) = "")
        {
            FileAppend, % "Log file created: " A_Now "`n`n---`n`n", % this.path.log
            If ErrorLevel
                this.error(A_ThisFunc, "Could not create a new log file.", 1)
                , status := 1
        }
        FileRead, err_log, % this.path.log
        this.err_log := err_log
        Return status
    }

    download_images()
    {
        Status := 0
        ; Loop through each streamer, download, and save their avatars and item drops
        For index, user in this.streamer_data
            For i, type in ["avatar","drop_pic"]
                ext         := ""
                , url       := user[type "_url"]
                , RegExMatch(url, this.rgx.ext, ext)
                , path      := this.path.streamers "\" user.username
                , file      := type "." ext
                , this.streamer_data[index][type "_loc"] := path "\" file
                , (this.img_getter(url, path, type "." ext) = 1) ? status := 1 : ""
        
        ; Get downloadable images
        For key, value in this.url
            InStr(value, ".png")
                ? (this.img_getter(this.url[key], this.path.img, key ".png") = 1 ? status := 1 : "")
                : ""
        
        Return Status
    }
    
    shutdown()
    {
        this.save_log()                                                 ; Save error logs
        ; Replace this with this.save_gui_settings()
        this.guis.main.save_main_xy()                                   ; Save last coords
        this.save_settings("main", "interval"                           ; Save check interval
            , this.guis.main.get_interval())
        
        ; MsgBox, 0x4, Cleanup, Delete downloaded images and other files?
        ; IfMsgBox, Yes
        ;     FileRemoveDir, % this.path.app, 1
        Return
    }
    
    quit(veryify=1)
    {
        If verify
        {
            MsgBox, 0x4, Exiting, % "Close " this.title "?"
            IfMsgBox, No
                Return
        }
        ExitApp
        Return
    }
    
    generate_notify_list()
    {
        this.notify_list := {}
        For index, user in this.streamer_data
            value := this.load_settings("notify_list", user.username)
            , this.notify_list[user.username] := (value = 1 ? 1 : 0)
        Return
    }
    
    folder_check()
    {
        Status := 0
        For key, path in this.path
            If (path = "")
                Continue
            Else If !InStr(path, ".") && !InStr(FileExist(path), "D")
            {
                FileCreateDir, % path
                If ErrorLevel
                    this.error(A_ThisFunc, "Unable to create directory: " this.path[A_LoopField])
                    , status := 1
            }
        
        ; Check settings file
        If (FileExist(this.path.settings) = "")
            FileAppend, % "[Settings]"
                . "`nCreated=" A_Now "`n`n"
                , % this.path.settings
        
        Return status
    }
    
    create_streamer_paths()
    {
        For index, user in this.streamer_data
            If !FileExist(this.path.streamers "\" user.username) || InStr(FileExist(path), "D")
            {
                FileCreateDir, % this.path.streamers "\" user.username
                If ErrorLevel
                    this.error(A_ThisFunc, "Unable to create streamer directory: " this.path.app "\" user.username)
                    , status := 1
            }
        Return
    }
    
    ; #######################
    ; ## Timing / Updating ##
    ; #######################
    heartbeat()
    {
        this.get_streamer_data()        ; Get fresh data
        ,this.guis.main.update_gui()    ; Update GUI with new info
        ,this.notify_check()            ; See if a notification needs to happen
        ;,this.next_beat()               ; Set when next update should occur
        Return
    }
    
    next_beat(time=0)
    {
        bf := ObjBindMethod(this, "heartbeat")
        time := (time = 0)  ? 1000 * 60 / this.interval : time * 1000
        SetTimer, % bf, Delete
        SetTimer, % bf, % -1 * Abs(time)
        Return
    }
    
    ;#####################
    ;##  Notifications  ##
    ;#####################
    notify_check()
    {
        MsgBox I want to go over this again. I don't feel like I wrote this correctly...
        
        notify := 0
        For index, user in this.streamer_data                       ; Compare fresh data to old notify list
            If (user.online)                                        ; Is user online?
            && (this.notify_list[user.username])                    ; Is user on the notify list?
            && (notify := this.notify_user(user))                   ; Did successful notification happen?
                Break
        MsgBox check on this part
        (notify = 0) ? this.systray.icon_flash(0) := True                        ; If no notifications, stop icon flash
        Return notify
    }
    
    notify_user(user_data)
    {
        ; If stream
        ;~ GuiControlGet, state,, % this.guis.gHwnd.notify_stream
        ;~ (state) ? this.streamer_maintenance(user_data) : ""
        ; If popup
        GuiControlGet, state,, % this.guis.gHwnd.notify_popup
        (state) ? this.notify_popup(user_data) : ""
        ;~ ; If beep
        ;~ GuiControlGet, state,, % this.guis.gHwnd.notify_beep
        ;~ (state) ? this.play_beep() : ""
        ;~ ; If icon
        ;~ GuiControlGet, state,, % this.guis.gHwnd.notify_icon
        ;~ (state) ? this.systray.icon_flash() : ""
        ;~ ; If file
        ;~ GuiControlGet, state,, % this.guis.gHwnd.notify_file
        ;~ (state) ? this.write_to_file(user_data) : ""
        Return
    }
    
    notify_popup(user)
    {
        Static active_popup := False
               ,snooze_time := 0
        MsgBox, Check on this.
        If active_popup
            Return
        
        If (A_TickCount < snooze_time)
            Return
        
        active_popup := True
        MsgBox, 0x4, Online!
            , % user.username " is now online!"
            . "`n`nHit yes to snooze popups for 15 minutes."
            . "`nHit no to disable popups."
        IfMsgBox, Yes
            snooze_time := A_TickCount + (15 * 50 * 1000)
        Else
            GuiControl,, % this.guis.gHwnd.notify_popup, 0
        Return
    }
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;;;;;;;;;;;;;;;;;;; TRYING TO FIGURE THIS SHIT OUT!!! ;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; .active
    ; .username
    ; .pid
    ; .time
    streamer_maintenance(user_data)
    {
        ; at this point a check has run, they're checked, and they're online
        Static hr_as_ms := 60*60*1000
        Static the_line := []
        strm := this.live_stream
        ;TrayTip, title, % "user_data.username: " user_data.username "`nstrm.user: " strm.user "`nstrm.time: " strm.time "`nA_TickCount: " A_TickCount 
        
        ; Check if user needs to be added to the line
        is_in_line := False
        For index, user in the_line
            If (is_in_line := (user_data.username = user.username))
                Break
        If !is_in_line
            the_line.Push(user_data)
        
        
        
        ;; THIS ALL NEEDS TO BE MOVED TO THE TIMER SECTION
        ;; ADDING A USER SHOULD ONLY OCCUR ON NOTIFICATION
        ;; UPDATING OF THE LINE SHOULD BE DONE ON A TIMER
        ;; THAT MEANS THAT the_line WILL NEED TO BE MOVED.
        ;~ ; If no active streamer, launch one
        ;~ If !this.live_stream.active
            ;~ this.update_live_stream(the_line.1)
        ;~ ; Else 
        ;~ Else If is_in_line
            
        ;~ Else If (the_line.1.username = this.live_stream.username)
        ;~ {
            ;~ time_running := this.convert_ms_to_time(this.live_stream.time, A_TickCount)
            ;~ MsgBox, 0x4, Warning, % "Another streamer was opened earlier and has not been running the required drop time."
                ;~ . "`nDo you still want to launch " user_data.username "'s page?"
                ;~ . "`n`nClick Yes to launch and No defer this uer until the current stream finishes."
            ;~ IfMsgBox, Yes
                ;~ this.kill_stream(strm.pid)
                ;~ , wait_list.InsertAt(1) := user_data
            ;~ Else wait_list.Push(user_data)
        ;~ }
        Return
    }
    
    ; active=1 sets everything to the current user data
    ; active=0 clears out all current info
    update_live_stream(active=1, user="")
    {
         this.live_stream.active   := (active ? True                            : 0)
        ,this.live_stream.username := (active ? user.username                   : "")
        ,this.live_stream.pid      := (active ? this.open_url(user.profile_url) : "")
        ,this.live_stream.time     := (active ? A_TickCount                     : 0)
        Return
    }
    
    kill_stream(pid)
    {
        WinClose, % "ahk_pid " pid,, 1000       ; Soft close
        Sleep, 1000
        If WinExist("ahk_pid " pid)             ; If win still exists, hard close
            WinKill, % "ahk_pid " pid,, 1000
        Return
    }
    
    ; ###################
    ; ## Streamer Info ##
    ; ###################
    get_streamer_data()
    {
        this.update_streamer_html()
        this.parse_streamer_html()
        Return
    }
    
    ; Scrape HTML from streamer page
    ; Saves html to this.html
    ; Returns 1 = success, 0 = failure
    update_streamer_html(retry=5)
    {
        web           := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        , this.html   := ""
        
        Try
            web.Open("GET", this.url.facepunch)
            ,web.Send()
        Catch status
        {
            this.error(A_ThisFunc, msg:="Error trying to get HTML from:`n" this.url.facepunch
                . "`nCatch: " status
                , option:=0)
        }
        
        If (--Retry < 1)
            this.error(A_ThisFunc, "Error getting data from site: " this.url.facepunch)
        Else If (web.ResponseText = "")
            SetTimer, % this._method(this, "update_streamer_html", retry), -400
        Else
            this.html := web.ResponseText
        Return
    }
    
    ; rust_dc.streamer_data properties:
    ; .profile_url      URL to user's twitch or youtube profile (whichever was provided by the site)
    ; .avatar_url       URL to user's gaming avatar
    ; .avatar_loc       Location on disk where avatar is saved
    ; .username         User's username (Redudant, right?)
    ; .online           User's online status
    ; .drop_pic_url     URL picture of this user's Rust drop
    ; .drop_pic_loc     Location on disk where Rust drop picture is saved
    ; .drop_name        The name of the drop
    ; .drop_hours       Watch time need to get drop
    parse_streamer_html()
    {
        strm_list   := []
        , info      := {}
        , start     := False
        , html      := this.html
        , html      := StrReplace(html  , "`r"    , "")
        , html      := StrReplace(html  , "`n"    , " ")
        , html      := RegExReplace(html, ">\s*?<", ">`n<")
        , match     := match1 := ""
        , this.streamer_data  := ""
        
        If (this.html = "")
        {
            this.error(A_ThisFunc, "No HTML was downloaded to parse."
                . "`nhtml: " this.html)
            Return 1
        }
        
        Loop, Parse, % this.html, `n
            If (start = False)                                                                           ; Skip all unnecessary starting lines
            {
                InStr(A_LoopField, "STREAMER DROPS") ? start := true : ""                                ; Check if start is finished
                Continue
            }
            Else If InStr(A_LoopField, "general-drops")                                                  ; Break when the user drops are done
                Break
            Else  RegExMatch(A_LoopField, this.rgx.profile_url  , match) ? info := {profile_url:match1}  ; Start of new user, get profile URL
                : RegExMatch(A_LoopField, this.rgx.avatar_url   , match) ? info.avatar_url   := match1   ; Get avatar's url
                : RegExMatch(A_LoopField, this.rgx.username     , match) ? info.username     := match1   ; Get username
                : RegExMatch(A_LoopField, this.rgx.online       , match) ? info.online       := (match1  ; Get online status
                                                                                            ="Live"?1:0) ; Converts "Live" to true
                : RegExMatch(A_LoopField, this.rgx.drop_pic_url , match) ? info.drop_pic_url := match1   ; Get URL for drop pic
                : RegExMatch(A_LoopField, this.rgx.drop_hrs     , match) ? info.drop_hours   := match1   ; Get pic name
                : RegExMatch(A_LoopField, this.rgx.drop_name    , match) ? info.drop_name    := match1   ; Get pic name
                : InStr(A_LoopField, "</a>")                             ? strm_list.Push(info)          ; End of users > write info
                : ""                                                                                     ; Else, do nothing
        
        For index, streamer in strm_list
            If InStr("account not found", streamer.username)
                strm_list[index].username := "Ban Pending"
        
        this.streamer_data := strm_list
        
        Return (this.streamer_data = "" ? 1 : 0)
    }
    
    Class guis
    {
        Static  gHwnd         := {main   :{opt  :{} }
                                         ,{note :{} }
                                         ,{over :{} }
                                 ,overlay:{}
                                 ,splash :{} }
        
        transparent_bg(hwnd)
        {
            GuiControl, +BackgroundTrans, % hwnd
            Return
        }
        
        Class main extends guis
        {
            Static  name        := "Main"
                    ,visible    := True
                    ,font       := {gb  :"s12 Norm Bold      Q5 cWhite"
                                   ,link:"s10 Norm Underline Q5 c00A2ED"
                                   ,def :"s10 Norm           Q5 cWhite"
                                   ,drk :"s10 Norm           Q5 cBlack"
                                   ,stat:"s10 Norm Bold      Q5 cBlack"
                                   ,smll:"s8  Norm           Q5 cWhite"}
            
            ; Initial generation of main GUI
            create()
            {
                gHwnd           := this.guis.gHwnd.main
                , add_method    := ObjBindMethod(rust_dc, "add_method_to_control", params:="")
                , pad           := 10
                , padh          := Round(pad/2)
                , padq          := Round(pad/4)
                , pad2          := Round(pad*2)
                , gui_h         := 800
                , card_w        := 200
                , card_h        := 270
                , btn_w         := 90
                , btn_h         := 30
                , strm_total    := rust_dc.streamer_data.MaxIndex()
                , cards_per_col := (strm_total < 10)
                                   ? 3 
                                   : Ceil(strm_total/3)
                , row_total     := Ceil(strm_total / cards_per_col)
                , opt_w         := 200
                , opt_h         := (row_total * card_h) + ((row_total-1) * pad)
                , gui_w         := opt_w + (cards_per_col * card_w) + (cards_per_col * pad)
                , err_gb_h      := 40
                , err_gb_w      := Round(gui_w/2 - pad*2)
                , err_txt_w     := Round(err_gb_w - 2)
                
                ; Creates the base GUI
                Gui, Main:New, +Caption -ToolWindow +HWNDhwnd, % rust_dc.title
                    gHwnd.gui := hwnd
                Gui, Main:Default
                Gui, Margin, % pad, % pad
                Gui, Color, 0x000000, 0x606060
                
                ; Build options area
                this.add_gui_options(pad, pad, opt_w, opt_h)
                
                ; Build streamer area right of options
                mx := 0
                For index, user in rust_dc.streamer_data
                    (++mx > cards_per_col ? mx := 1 : "")
                    , my := Ceil(A_Index/cards_per_col) 
                    , x  := (card_w * (mx-1)) + (pad*mx) + opt_w
                    , y  := (card_h * (my-1)) + (pad*my)
                    , this.add_card(index, user, card_w, card_h, x, y)
                
                ; Add error area to display errors as they come
                Gui, Add, GroupBox, w%err_gb_w% h%err_gb_h% xm y+%pad% +HWNDhwnd Section, Error Messages:
                    gHwnd.error_gb := hwnd
                Gui, Font, % this.font.smll
                Gui, Add, Edit, w%err_gb_w% xp yp+20 ReadOnly R1 +HWNDhwnd, FAKE ERROR MESSAGE FOR TESTING!
                    gHwnd.error_txt := hwnd
                
                ; Add all the buttons to the bottom area
                ; Exit button
               x := gui_w - btn_w - pad
                Gui, Font, % this.font.def
                Gui, Add, Button, w%btn_w% h%btn_h% x%x% y+-%btn_h% +HWNDhwnd, Exit
                    add_method(hwnd, rust_dc, "quit")
                ; Hide button
                x := pad + btn_w
                Gui, Add, Button, w%btn_w% h%btn_h% xp-%x% yp +HWNDhwnd, Hide
                    add_method(hwnd, this, "Hide")
                ; Uncheck all button
                x := pad + btn_w
                Gui, Add, Button, w%btn_w% h%btn_h% xp-%x% yp +HWNDhwnd, Uncheck All
                    add_method(hwnd, this, "checkbox_all_streamers", 0)
                ; Check all button
                x := pad + btn_w
                Gui, Add, Button, w%btn_w% h%btn_h% xp-%x% yp +HWNDhwnd, Check All
                    add_method(hwnd, this, "checkbox_all_streamers", 1)
                
                ; Add overlay button
                x := (pad2 + btn_w)
                Gui, Add, Button, w%btn_w% h%btn_h% xp-%x% yp +HWNDhwnd, Overlay
                ;    add_method(hwnd, rust_dc.guis.overlay, "Show")
                
                ; Allows the gui to be clicked and dragged
                bf := ObjBindMethod(this, "WM_LBUTTONDOWN", A_Gui)
                OnMessage(0x201, bf)
                bf := ObjBindMethod(this, "WM_EXITSIZEMOVE", A_Gui)
                OnMessage(0x232, bf)
                Return
            }
            
            add_gui_options(start_x, start_y, max_w, max_h)
            {
                add_method  := ObjBindMethod(rust_dc, "add_method_to_control", params:="")
                , gHwnd     := this.guis.gHwnd.main.opt
                , pad       := 10
                , pad2      := pad * 2
                , pad3      := pad * 3
                , padh      := pad / 2
                , pad_gb    := pad * 2.5
                , pad_ul    := pad_gb + pad
                , x_left    := start_x + pad
                , gb_w      := max_w - pad
                
                Gui, Main:Default
                ; Updater section
                upd_btn_w   := gb_w - pad2
                , upd_btn_h := 30
                , upd_gb_h  := upd_btn_h + pad_ul
                Gui, Font, % this.font.gb
                Gui, Add, GroupBox, w%gb_w% h%upd_gb_h% x%start_x% y%start_y% Section +HWNDhwnd, Update Checker:
                    gHwnd.updater_gb := hwnd
                    last_gb := upd_gb_h
                Gui, Font, % this.font.drk
                Gui, Add, Button, w%upd_btn_w% h%upd_btn_h% xp+%pad% yp+%pad_gb% +HWNDhwnd +Disabled, Initializing...
                    gHwnd.updater_btn := hwnd
                    ;this.start_update_check_timer() ; the act of starting this should be moved to the start/finish section
                    add_method(hwnd, this, "run_update")
                
                ; Refresh Frequency
                slide_min   := 1
                , slide_max := 10
                , ref_def_h := 20
                , ref_bud_w := 15
                , ref_sld_w := gb_w - (ref_bud_w*2) - pad2
                , ref_txt_w := gb_w - pad2
                , ref_gb_h  := ref_def_h*2 + pad_ul
                y := last_gb + pad
                Gui, Font, % this.font.gb
                Gui, Add, GroupBox, w%gb_w% h%ref_gb_h% xs ys+%y% Section, Check Frequency:
                    last_gb := ref_gb_h
                Gui, Font, % this.font.def
                Gui, Add, Text, w%ref_bud_w% h%ref_def_h% xs+%pad% yp+%pad_gb% +Center, 1
                Gui, Add, Slider, w%ref_sld_w% h%ref_def_h% x+0 yp range%slide_min%-%slide_max% +HWNDhwnd Line1 ToolTip TickInterval AltSubmit
                    , % this.load_interval()
                    gHwnd.interval_sld := hwnd
                    add_method(hwnd, this, "interval_slider_moved")
                    this.interval_slider_moved(hwnd,"","")
                Gui, Add, Text, w%ref_bud_w% h%ref_def_h% x+0 yp +Center, 10
                Gui, Add, Text, w%ref_txt_w% h%ref_def_h% xs+%pad% y+%padh% +Center +HWNDhwnd, Initializing...
                    gHwnd.cps_txt := hwnd
                    this.update_interval_per_second()
                
                ; Quick link to twitch rewards claim page
                link_list   := [{txt:"Twitch Rewards Page"  , url:rust_dc.url.twitch_rewards   }
                               ,{txt:"Streamer Drops Page"  , url:rust_dc.url.facepunch        }
                               ,{txt:"AHK Drop Alert Home"  , url:rust_dc.url.git_homepage     } ]
                , ql_txt_w  := gb_w - pad2
                , ql_txt_h  := 16
                , ql_gb_h  := ((ql_txt_h + padh) * link_list.MaxIndex()) + pad_ul - padh
                y := last_gb + pad
                Gui, Font, % this.font.gb
                Gui, Add, Groupbox, w%gb_w% h%ql_gb_h% xs ys+%y% +HWNDhwnd Section, Quick Links:
                    last_gb := ql_gb_h
                Gui, Font, % this.font.link, Consolas
                For index, data in link_list
                {
                    y := (index = 1 ? pad_gb : (ql_txt_h+padh))
                    Gui, Add, Text, w%ql_txt_w% h%ql_txt_h% xs+%pad% yp+%y% +HWNDhwnd, % data.txt
                    add_method(hwnd, this, "open_url", data.url)
                }
                Gui, Font
                
                ; Notify Options
                noti_cb_w   := gb_w - pad2
                , noti_cb_h := 16
                , noti_edt_h:= 20
                , noti_gb_h := (rust_dc.notify_opt.MaxIndex() * (noti_cb_h + padh)) + pad_ul - padh
                y := last_gb + pad
                Gui, Font, % this.font.gb
                Gui, Add, Groupbox, w%gb_w% h%noti_gb_h% xs ys+%y% +HWNDhwnd Section, Notify Options:
                    last_gb := noti_gb_h
                Gui, Font, % this.font.def
                For index, data in rust_dc.notify_opt
                {
                    Gui, Add, Checkbox, % "w" noti_cb_w " h" noti_cb_h " xs+" pad " " (index = 1 ? " ys+" pad_gb : " y+" padh) " +HWNDhwnd", % data.txt
                    gHwnd["notify_" data.type] := hwnd
                    value := (rust_dc.load_settings("Notify_Options", data.type) > 0 ? 1 : 0)
                    GuiControl,, % hwnd, % value
                    add_method(hwnd, this, "notify_checkbox_checked", data.type, hwnd)
                    this.notify_checkbox_checked(data.type, hwnd)
                }
                Gui, Font
                
                ; Overlay settings
                ; Let's build a list:
                ; box width
                ; box height
                ; # of cols
                ; bg color
                ; online color
                ; offline color
                ; flash color
                ; opacity
                ; 
                
                opt_list := [{txt:"Opacity" ,type:"Slider"     , rangel:1, rangeh:rust_dc.streamer_data.MaxIndex()}
                            ,{txt:"Columns" ,type:"Slider"     , rangel:1, rangeh:100}
                            ,{txt:"Lock"    ,type:"Checkbox"   } ]
                txt_h       := 16
                , txt_w     := gb_w - pad2
                , buddy_h   := 20
                , buddy_w   := 15
                , cb_h      := 16
                , cb_w      := gb_w - pad2
                , slider_h  := 20
                , slider_w  := gb_w - (buddy_w*2) - pad
                , ovr_gb_h  := (3*txt_h) + (2*slider_h) + (pad*5) + pad_ul
                y := last_gb + pad
                Gui, Font, % this.font.gb
                Gui, Add, Groupbox, w%gb_w% h%ovr_gb_h% xs ys+%y% +HWNDhwnd Section, Overlay Settings:
                    last_gb := ovr_gb_h
                Gui, Font, % this.font.def
                Gui, Add, Checkbox, w%cb_w% h%cb_h% xs+%pad% ys+%pad_gb%, Click-Through (Lock)
                    ;gHwnd.overlay_click := hwnd
                ;Gui, Add, Checkbox, w%cb_w% h%cb_h% xs+%pad% ys+%pad_gb%, Click-Through (Lock)
                    ;gHwnd.overlay_click := hwnd
                
                ; Donations quick links
                link_list   := [{txt:"Ko-Fi Donation"   , url:rust_dc.url.patreon  }
                               ,{txt:"Patreon Donation" , url:rust_dc.url.kofi     } ]
                , ql_txt_w  := gb_w - pad2
                , ql_txt_h  := 16
                , ql_gb_h  := (ql_txt_h + padh) * link_list.MaxIndex() + pad_ul
                y := max_h - ql_gb_h + pad
                Gui, Font, % this.font.gb
                Gui, Add, Groupbox, w%gb_w% h%ql_gb_h% xs y%y% +HWNDhwnd Section, Donate:
                    last_gb := ql_gb_h
                Gui, Font, % this.font.link, Consolas
                For index, data in link_list
                {
                    y := (index = 1 ? " ys+" pad_gb : " y+" padh)
                    Gui, Add, Text, w%ql_txt_w% h%ql_txt_h% xs+%pad% %y% +HWNDhwnd, % data.txt
                    add_method(hwnd, this, "open_url", data.url)
                }
                Gui, Font
                
                ; Blank 
                ;y := last_gb + pad
                ;Gui, Font, Bold
                ;Gui, Add, Groupbox, w%gb_w% h%ql_gui_h% xs ys+%y% +HWNDhwnd Section, Quick Links:
                ;    last_gb := ql_gui_h
                ;Gui, Font, s10 Norm cWhite
                Return
            }
            
            add_card(index, user, sw, sh, sx, sy)
            {
                add_method      := ObjBindMethod(rust_dc, "add_method_to_control", params:="")
                , pad           := 10
                , pad2          := pad*2
                , padh          := pad/2
                , padq          := pad/4
                , online_w      := 70
                , online_h      := 20
                , avatar_w      := 50
                , avatar_h      := 50
                , drop_pic_w    := sw - pad
                , drop_pic_h    := drop_pic_w
                , notify_cb_w   := sw/2
                , notify_cb_h   := 20
                , action_btn_w  := (drop_pic_w - avatar_w - pad2) / 2
                , action_btn_h  := avatar_h - notify_cb_h - pad
                , gHwnd         := rust_dc.guis.gHwnd.main[username] := {}
                
                Gui, Main:Default
                Gui, Font, % this.font.gb
                ; Create groupbox border and add username to groupbox
                Gui, Add, GroupBox, w%sw% h%sh% x%sx% y%sy%, % user.username
                
                ; Add online background to groupbox border
                x := sw - online_w - padh
                Gui, Add, Picture, w%online_w% h%online_h% xp+%x% yp +HWNDhwnd, % rust_dc.path["img_" (user.online ? "online" : "offline")]
                    gHwnd.online_pic := hwnd
                ; Add online text 
                Gui, Font, % this.font.stat
                Gui, Add, Text, w%online_w% h%online_h% xp yp+2 +Center +HWNDhwnd, % user.online ? "LIVE" : "OFFLINE"
                    this.transparent_bg(hwnd)
                    gHwnd.online_txt := hwnd
                
                ; Drop_pic image
                x := sx + padh
                Gui, Add, Picture, w%drop_pic_w% h%drop_pic_h% x%x% yp+20 +Border, % user.drop_pic_loc
                ; Drop_name description
                h := 30
                Gui, Font, % this.font.def
                Gui, Add, Text, wp h%h% xp y+-%h% HWNDhwnd +Center +Border +0x200, % user.drop_name
                
                ; User's icon
                Gui, Add, Picture, w%avatar_w% h%avatar_h% xp y+0 +Border +Section, % user.avatar_loc
                ; Add snooze/dismiss buttons
                Gui, Add, Button, w%action_btn_w% h%action_btn_h% x+%padh% yp+%padh% +HWNDhwnd, Snooze
                    gHwnd.snooze_btn := hwnd
                    ;add_method(hwnd, this, "alert_snooze", 1)
                Gui, Add, Button, w%action_btn_w% h%action_btn_h% x+%pad% yp +HWNDhwnd, Dismiss
                    gHwnd.dismiss_btn := hwnd
                    ;add_method(hwnd, this, "alert_dismiss", 1)
                
                ; Add notify checkbox
                Gui, Font, % this.font.def
                w := sw - avatar_w - pad2
                y := notify_cb_h
                x := avatar_w + pad
                Gui, Add, Checkbox, w%w% h%notify_cb_h% xs+%x% y+%padh% +HWNDhwnd, Notify Me!
                    gHwnd.notify_cb := hwnd
                    add_method(hwnd, this, "notify_box_checked", name)
                    GuiControl,, % hwnd, % rust_dc.notify_list[name]
                ; Hide the buttons until they're needed
                GuiControl, Hide, % gHwnd.snooze_btn
                GuiControl, Hide, % gHwnd.dismiss_btn
                
                Return
            }
            
            ; 1 = Check all, 0 = Uncheck all
            checkbox_all_streamers(state)
            {
                For index, user in rust_dc.streamer_data
                    GuiControl,, % this.gHwnd.main[user.username].notify_cb, % state
                Return
            }
            
            notify_checkbox_checked(label, hwnd)
            {
                GuiControlGet, state,, % hwnd
                rust_dc.save_settings("Notify_Options", label, state)  ; Save to settins file
                Return
            }
            
            overlay_checkbox_checked(label, hwnd)
            {
                MsgBox still needs to be written. %A_ThisFunc%
                Return
            }
            
            load_interval()
            {
                i := rust_dc.load_settings("main", "interval")
                Return (i = "Err") ? 6
                     : (i < 1)     ? 1
                     : (i > 10)    ? 10
                     :               i
            }
            
            get_interval()
            {
                GuiControlGet, interval, , % this.gHwnd.main.interval_sld
                Return interval
            }
            
            update_interval_per_second()
            {
                GuiControl, 
                    , % this.gHwnd.main.cps_txt
                    , % "Checking every " Round(60 / this.get_interval()) " seconds" 
                Return 
            }
            
            start_update_check_timer()
            {
                bf  := ObjBindMethod(rust_dc, "update_check")
                SetTimer, % bf, -60000
                Return
            }
            
            interval_slider_moved(hwnd)
            {
                this.update_interval_per_second()
                rust_dc.save_settings("main", "interval", this.get_interval())
                Return
            }
            
            notify_box_checked(name, hwnd, GuiEvent, EventInfo, ErrLevel:="")
            {
                GuiControlGet, state, , % hwnd                  ; Get check state
                rust_dc.notify_list[name] := state                 ; Update notify list
                rust_dc.save_settings("notify_list", name, state)  ; Save to settins file
                ; This should be changed to "update_timer" or something else. this.heartbeat()                                ; Do a check
                Return
            }
            
            update_gui()
            {
                txt := ""
                For index, user in rust_dc.streamer_data
                {
                    ; Get current text
                    GuiControlGet, txt,, % this.gHwnd[user.username].online_txt
                    ; Update status on change
                    If ( user.online && (txt = "offline")) 
                    || (!user.online && (txt = "live")   )
                    {
                        GuiControl,, % this.gHwnd[user.username].online_pic
                            , % rust_dc.path["img_" (user.online ? "online" : "offline")]
                        GuiControl,, % this.gHwnd[user.username].online_txt
                            , % (user.online ? "LIVE" : "OFFLINE")
                    }
                }
                Return
            }
            
            WM_LBUTTONDOWN()
            {
                If (A_Gui = "Main")
                {
                    MouseGetPos,,,, con
                    If !InStr(con, "button")
                    && !InStr(con, "trackbar321")
                    && !InStr(con, "edit")
                        SendMessage, 0x00A1, 2,,, A
                }
                Return
            }
            
            WM_EXITSIZEMOVE()
            {
                this.save_main_xy()
                Return
            }
            
            get_main_xy()
            {
                WinGetPos, x, y,,, % "ahk_id " rust_dc.guis.main.gui
                this.last_x := (x*0 = 0) ? x : 0
                this.last_y := (y*0 = 0) ? y : 0
                Return
            }
            
            load_main_xy()
            {
                 x := rust_dc.load_settings("main", "gui_last_x")
                ,y := rust_dc.load_settings("main", "gui_last_y")
                ,this.last_x := (x = "Err") ? 0 : x
                ,this.last_y := (y = "Err") ? 0 : y
                Return
            }
            
            save_main_xy()
            {
                this.get_main_xy()
                ,rust_dc.save_settings("main", "gui_last_x", this.last_x)
                ,rust_dc.save_settings("main", "gui_last_y", this.last_y)
                Return
            }
            
            Show()
            {
                this.load_main_xy()
                Gui, Main:Show, % "AutoSize x" this.last_x " y" this.last_y, % rust_dc.title
                this.visible := True
                rust_dc.guis.systray.update_tray_show_hide()
            }
            
            Hide()
            {
                this.save_main_xy()
                Gui, Main:Hide
                this.visible := False
                rust_dc.systray.update_tray_show_hide()
            }
            
            Toggle()
            {
                this.visible ? this.Hide() : this.Show()
            }
        }
        
        Class splash extends guis
        {
            Static  name    := "Splash"
                    ,font   := {shadow  :"s20 cBlack Norm Bold"
                               ,txt     :"s20 cWhite Norm" }
            start(first_msg)
            {
                pad         := 10
                , padO      := 12
                , pad2      := pad*2
                , padO2     := padO*2
                , gui_w     := 220
                , gui_h     := 220
                , txt_w     := gui_w - pad2
                , txt_h     := gui_h - pad2
                , scrn_t    := scrn_r := scrn_b := scrn_l := 0
                , rust_dc.get_monitor_workarea(scrn_t, scrn_r, scrn_b, scrn_l)
                , rust_dc.img_getter(rust_dc.url.img_rust_symbol, rust_dc.path.img, "img_rust_symbol.png")
                
                Gui, Splash:New, -Caption +HWNDhwnd +Border +ToolWindow +AlwaysOnTop
                    this.gHwnd.gui_splash := hwnd
                Gui, Splash:Default
                Gui, Margin, % pad, % pad
                Gui, Color, 0x000001
                Gui, Add, Picture, w%gui_w% h%gui_h% x0 y0, % rust_dc.path.img_rust_symbol
                Gui, Add, Text, w%txt_w% h%txt_h% x%pad% y%pad% +HWNDhwnd +Center +BackgroundTrans, % ""
                    this.gHwnd.spalsh_txt_shadow := hwnd
                Gui, Font, % , Consolas
                Gui, Add, Text, w%txt_w% h%txt_h% x%padO% y%padO% +HWNDhwnd +Center +BackgroundTrans, % ""
                    this.gHwnd.splash_txt := hwnd
                x := scrn_r - scrn_l - gui_w
                y := scrn_b - scrn_t - gui_h
                Gui, Show, w%gui_w% h%gui_h% x%x% y%y%
                ;this.animate()
                Return
            }
            
            update(txt)
            {
                Gui, Splash:Default
                ; Two fonts to create a shadow effect
                Gui, Font, % "s20 cBlack Bold", Consolas
                GuiControl,, % this.gHwnd.spalsh_txt_shadow, % "`n" txt
                Gui, Font, % "s20 cWhite Norm", Consolas
                GuiControl,, % this.gHwnd.splash_txt, % "`n" txt
                Gui, Splash:Show, AutoSize
            }
            
            animate()
            {
                ;MsgBox animation code here
                Return
            }
            
            finish()
            {
                bf := ObjBindMethod(this, "Destroy")
                SetTimer, % bf, -700
            }
            
            Destroy()
            {
                Gui, Splash:Destroy
            }
        }
        
        Class overlay extends rust_dc
        {
            Static  name        := "Overlay"
                    ,visible    := False
            
            create()
            {
                Gui, % this.name ":New", -Caption -ToolWindow +HWNDhwnd
                Gui, % this.name ":Default"
                Return
            }
          
            Show()
            {
                MsgBox, Overlay not implemented yet.
                ;x := this.last_x
                ;y := this.last_y
                ;h := this.get_overlay_height()
                ;w := this.get_overlay_width()
                ;Gui, % this.name ":Show", w%w% h%h% x%x% y%y%
                Return
            }
            
            Hide()
            {
                Gui, % this.name ":Hide"
                Return
            }
        }
    }
    
    ; Show/Hide Gui (default)
    ; Overlay Control
    ; Links
    ; ---
    ; Exit
    ; Donate
    Class systray extends rust_dc
    {
        Static flash_stop := 0
        
        create()
        {
            Menu, Tray, NoStandard                              ; Clean slate
            this.icon_reset()                                   ; Default icon
            
            bf := ObjBindMethod(rust_dc.guis.main, "toggle")
            Menu, Tray, Add, Show, % bf                         ; Show/hide option
            Menu, Tray, Default, 1&                             ; Set show/hide to default
            
            ; Need to add overlay controls
            ; Consider changing the default from toggling the gui to toggling the overlay
            ;~ bf := ObjBindMethod(this, "open_url", this.url.twitch_rewards)
            ;~ Menu, Tray, Add, Overlay, % bf       ; Rewards page
            
            Menu, Tray, Add                                     ; DIVIDER Links
            bf := ObjBindMethod(this, "open_url", rust_dc.url.twitch_rewards)
            Menu, Tray, Add, Drop Reward Claim Page, % bf       ; Rewards page
            bf := ObjBindMethod(this, "open_url", rust_dc.url.facepunch)
            Menu, Tray, Add, Facepunch Twitch Page, % bf        ; Rust update/blog page
            bf := ObjBindMethod(this, "open_url", rust_dc.url.facepunch_blog)
            Menu, Tray, Add, Facepunch Twitch Page, % bf        ; Facepunch home page
            bf := ObjBindMethod(this, "open_url", rust_dc.url.git_homepage)
            Menu, Tray, Add, Github Home Page, % bf             ; Github Repo
            bf := ObjBindMethod(this, "open_url", rust_dc.url.git_homepage)
            Menu, Tray, Add, Donate, % bf                       ; Donation link
            
            Menu, Tray, Add                                     ; DIVIDER Exit area
            bf := ObjBindMethod(this, "quit")
            Menu, Tray, Add, Exit, % bf                         ; Exit option
            Return
        }
        
        icon_reset()
        {
            Menu, Tray, Icon, % rust_dc.path.img_rust_symbol     ; Set Icon
        }
        
        update_tray_show_hide()
        {
            Menu, Tray, Rename, 1&, % (rust_dc.guis.main.visible ? "Hide" : "Show")
        }
        
        icon_flash_stop()
        {
            this.flash_stop := True
            Return
        }
        
        icon_flash()
        {
            Static  toggle      := 0
                    , running   := 0
            
            toggle := !toggle
            Menu, Tray, Icon, % rust_dc.path["img_rust_symbol" (toggle ? "" : "_2")]
            bf := ObjBindMethod(this, "icon_flash")
            
            If (this.flash_stop)
            {
                this.flash_stop := False
                SetTimer, % bf, Delete
                running := 0
                Return
            }
            Else If (running)
                Return
            
            SetTimer, % bf, Delete
            running := 1
            SetTimer, % bf, 850
            Return
        }
        
    }
    
    ; ########################
    ; ##  Common Functions  ##
    ; ########################
    add_method_to_control(hwnd, object_name, method_name, params*)
    {
        bf := ObjBindMethod(object_name, method_name, params*)
        GuiControl, +g, % hwnd, % bf
        Return
    }
    
    ; Get the non-reserved area of a screen m_num
    get_monitor_workarea(ByRef mTop, ByRef mRight, ByRef mBottom, ByRef mLeft, m_num=0)
    {
        If (m_num = 0)
            SysGet, m_num, MonitorPrimary
        SysGet, m, MonitorWorkArea, % m_num
        Return
    }
    
    update_check(verbose := 0)
    {
        online_version  := Trim(this.web_get(this.url.online_version), " `t`r`n")
        update_found    := 0
        Loop, % StrLen(this.version)
            If (SubStr(this.version, A_Index, 1) = SubStr(online_version, A_Index, 1))
                Continue
            Else
            {
                update_found := 1
                If verbose
                {
                    MsgBox, 0x4, Update Available!
                    , % "A new version of " this.title " is available.`nWould you like to download it?"
                    IfMsgBox, Yes
                        this.run_update()
                }
                Break
            }
        
        ; Changes the update area of the GUI depending on if an update is available
        Gui, Main:Default
        GuiControl                                          ; Set the Updater Groupbox text and color
            , % "+c" (update_found ? "FF0000" : "00FF00")   ; Red if update found, green if up-to-date
            , % this.guis.gHwnd.updater_gb
        Gui, Font, Norm cBlack
        GuiControl, Text, % this.guis.gHwnd.updater_btn     ; Update text
            , % (update_found ? "Update Available!" : "Up To Date!")
        GuiControl, % (update_found ? "Enable" : "Disable") ; Enable button if update available
        , % this.guis.gHwnd.updater_btn
        Return
    }
    
    ; #############
    ; ## Updater ##
    ; #############
    run_update()
    {
        status      := 0
        , dq        := """"
        , url       := this.url.ahk_rust_checker
        , temp_path := this.path.temp
        , orig_loc  := A_ScriptDir
        , file_name := A_ScriptName
        , upd_name  := "updater.ahk"
        
        MsgBox, 0x1, Confirm Update, % "Click OK to update.`nClick Cancel to go back."
        IfMsgBox, Cancel
            Return
        
        ; Get files
        UrlDownloadToFile, % url, % temp_path "\" A_ScriptName
        (status := ErrorLevel)
            ? this.error(A_ThisFunc, "Could not download file from url and save to location."
                . "`nurl: " url "`nlocation: " temp_path "\" file_name) : ""
        
        ; Code to build an updater script
        code := "#SingleInstance Force"
            . "`n#NoEnv"
            . "`nSleep, 1000"
            . "`nFileMove, % A_Args.1, % A_Args.2, 1"
            . "`nRun, % A_AhkPath A_Space A_Args.2"
            . "`nExitApp"
        source      := dq temp_path "\" file_name dq
        destination := dq A_ScriptFullPath dq
        updated     := 1
        path        := temp_path "\" upd_name
        
        ; Ensure temp folder is empty
        this.temp_cleanup()
        
        ; Create updater script
        FileAppend, % code, % path
        (status := ErrorLevel)
            ? this.error(A_ThisFunc, "Update Failed:"
                . "`nCould not write updater file."
                . "`nPath: " path ) : ""
        ; Run updater and exit this script
        Run, % A_AhkPath " " temp_path "\" upd_name
            . " " source " " destination " " updated
        ExitApp
        Return
    }
    
    ; Empty the temp folder
    temp_cleanup()
    {
        FileDelete, % this.path.temp "\*.*"
    }
    
    ; ##########################
    ; ##  General Functionss  ##
    ; ##########################
    ; Get image from url
    ; 
    img_getter(url, path, file_name, overwrite=0)
    {
        Status := 0
        If (FileExist(path) = "")
        {
            FileCreateDir, % path
            (status := ErrorLevel)
                ? this.error(A_ThisFunc, "Save path does not exist and could not be created."
                    . "`npath: " path) : ""
        }
        
        If (FileExist(path "\" file_name) = "") || (overwrite = 1)
        {
            UrlDownloadToFile, % url, % path "\" file_name
            (status := ErrorLevel)
                ? this.error(A_ThisFunc, "Could not download file from url and save to location."
                    . "`nurl: " url "`nlocation: " path "\" file_name) : ""
        }
        
        Return status
    }
    

    web_get(url)
    {
        web := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        Try
            web.Open("GET", url), web.Send()
        Catch
        {
            this.error(A_ThisFunc, "Error getting data from site: " url)
            Return 1
        }
        Return web.ResponseText
    }
    
    play_beep()
    {
        Static running := False
        
        If running
            Return
        
        running := True
        Loop, 5
            SoundPlay, % "*" 16, 1
        running := False
        Return
    }
    
    write_to_file(user_data)
    {
        MsgBox still need to write this function.`n%A_ThisFunc%
        Return
    }
    
    open_url(url)
    {
        Run, % url,,, pid
        Return pid
    }
    
    ; Converts a time from ms to human format
    ; If 2 times are passed, the difference between them is returned
    convert_ms_to_time(ms_in_1, ms_in_2 := "")
    {
        static ms_convert  := [{txt:"day" , ms:86400000}
                              ,{txt:"hour", ms: 3600000}
                              ,{txt:"min" , ms:   60000}
                              ,{txt:"sec" , ms:    1000}]
        result      := ""
        , time      := ""
        , ms_total  := (ms_in_2 != "")
                    ? Abs(ms_in_1 - ms_in_2)
                    : ms_in_1
        For index, set in ms_convert
            time := Floor(ms_total/set.ms)
            , (time > 0)
                ? (result .= time " " set.txt " "
                  ,ms_total -= time * set.ms )
                : ""
        Return result
    }
    
    ; Used to create class method boundfuncs (boundmeths?)
    _method(obj, method, param="")
    {
        bf := ObjBindMethod(obj, method, param*)
        Return bf
    }
    
    save_log()
    {
        While (FileExist(this.path.log) != "")
            FileDelete, % this.path.log
        FileAppend, % this.err_log, % this.path.log
    }
    
    ; Load settings from ini file
    ; Returns "Err" if not able to load setting.
    load_settings(section, key)
    {
        IniRead, value, % this.path.settings, % section, % key, % "Err"
        Return value
    }
    
    ; Save settings to ini file
    save_settings(section, key, value)
    {
        IniWrite, % value, % this.path.settings, % section, % key
        Return 
    }
    
    ; Used to remove old streamer entries in the settings.ini file
    clean_settings()
    {
        MsgBox, Still need to write this method: %A_ThisFunc%
        ; Make an array of streamers
        ; Loop through settings.ini
        ; If no match is found
        ; If streamer not found 
        Return
    }
    
    msg(msg, opt:=0x0)
    {
        MsgBox, % opt, % this.title, % msg
    }
    
    ; Gives a red to white color changing effect to the error group box text
    err_notify_color_changer(rgb=0xFF0000)
    {
        If (rgb >= 0xFFFFFF)
            Return
        GuiControl, c%rgb%, % this.guis.gHwnd.main.error_txt 
        rgb += 0x000101
        bf := ObjBindMethod(this, "err_notify_color_changer", rgb)
        Sleep, 1
        SetTimer, % bf, -100
        Return
    }
    
    ; Options:
    ;  0 = just log error
    ;  1 = Verbose error message
    ; -1 = Close script
    error(call, msg, option:=0)
    {
        ; Log error
        this.err_last   := A_Now "`nCall: " call "`nMessage: " msg
        this.err_log    .= this.err_last "`n`n---`n`n"
        ; Update gui
        GuiControl,, % this.guis.gHwnd.error_txt, % this.err_last
        this.err_notify_color_changer()
        ; Handle options
        If (option = -1)
            ExitApp
        If (option = 1)
        {
            MsgBox, 0x4, Error, Do you want to reload the script and try again?
            IfMsgBox, Yes
                Reload
        }
        ; Always return 1
        Return 1
    }
    
}

; Used for troubleshooting
msg(txt)
{
    MsgBox, % txt
    Return
}

/*
FAQ
Answering any questions here and also taking suggestions.

Is this going to log my password/keystrokes?  
No... It's an open source program. You can look at the code. The only data transmission going on is to the facepunch servers to get up-to-date HTML and to GitHub to get files like images. No other send/get requests are sent.  
If you're still doubtful, don't use it. I R N0T tRY1Ng 2 HAX0R UR .nfo ??\_(-_-)_/??  
The purpose of this is to help the community get skins.  

Will this auto-log into my account and save my passwords?
Nope. The script is open source and there's no good way to securely store your password. Thus, all logging in/out has to be done by the user.  
Plus, this protects me because no one can be like "Your program let me info out!" Pfft. No, it didn't.

Can I set it to automatically open up the streamer when they come on?  
Yes. It's one of the "notification" options. But it's the user's responsibility to be logged into twitch and to have their accounts linked. There are instructions about this at script launch.  
You can watch other twitch streams, but do it in an incognito/private window and don't be logged into your account. If you're logged in, it can affect you getting credit for the current drop.

What kind of alerts does it give?  
I haven't designed all the options, but as of now, here's what I have:  

* Open up user's stream page.
* Pop-up window message (just a standard Windows message box).  
* System beeping. Can be continuous. (I'd like to put in the ability for you to use . (dots),  (spaces), and - (dashes) to make neat little beats. But this will come later.)
* Link to a video/site that has media you want to play. The script will launch that page when the person you want comes on. For example, you'd paste something like this in the box: https://www.youtube.com/watch?v=dQw4w9WgXcQ
* Flashing notification icon or repeating pop-up/toast notifications.
* While it's currently not an option, I would like to add a way to send an email and/or text as a notification.
* Write-to-file. Most won't use this option, but it does allow for an extrenal apps to get the current status of streamers and their key info without having to code their own solution.  
A prime example of use for this would be for live posting to a discord server.

Sometimes I mute my computer and forget.  
That's not a question. But I understand. There an anti-mute setting that ensures mute isn't able, as well as a "set volume" setting.

How much does this cost?  
It's free.ninety-nine for everyone. I believe in open source for most things. I may add a "donation" button for anyone who would like to kick a tip my way. But the only thing you're EXPECTED to do is get skins easier.

It burns when I pee. What should I do?  
Always where a rubber, Jimmy. The sea can be dangerous. (Also, this is not AHK Rust Drop Checker question...)

Will this notify me when my current drop is done?   
While I do not have that programmed in, it is something I could add down the line. So, yes, but not yet.
*/
