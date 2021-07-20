#SingleInstance Force
#Warn
#NoEnv
rust_checker.Start()
Return

*F1::rust_checker.main_gui.Toggle()
*Escape::ExitApp

~^s::
    IfWinActive, % A_ScriptName
    {
        Run, % A_ScriptFullPath
        Sleep, 100
        ExitApp
    }
Return

/*
error codes
-1 = HTML can't be downloaded
-2 = Error parsing HTML
-3 = No streamer data to access
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

Class rust_checker
{
    Static  title           := "AHK Rust Drop Checker"
            , version       := "1.0.0.1"
            , html          := ""
            , err_last      := ""
            , err_log       := ""
            , notify_list   := {}
            , update_freq   := 60
    ; Object tracking
    Static  streamer_data   := {0:{profile_url      : ""    ; URL to user's twitch or youtube profile (whichever was provided by the site)
                                  ,avatar_url       : ""    ; URL to user's gaming avatar
                                  ,avatar_loc       : ""    ; Location on disk where avatar is saved
                                  ,username         : ""    ; User's username (Redudant, right?)
                                  ,status           : 0     ; User's status of online or offline
                                  ,drop_pic_url     : ""    ; URL picture of this user's Rust drop
                                  ,drop_pic_loc     : ""    ; Location on disk where Rust drop picture is saved
                                  ,drop_name        : ""    ; The name of the drop
                                  ,drop_hours       : 2 } } ; Watch time need to get drop
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
                               ,write_file          : ""}
    Static  url             := {git_homepage        : "https://github.com/0xB0BAFE77/AHK_Rust_Drop"
                               ,img_online          : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/img/Online%20Blank%203D.png"
                               ,img_offline         : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/img/Offline%20Blank%203D.png"
                               ,img_rust_symbol     : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/img/Rust_Symbol.png"
                               ,img_rust_symbol_2   : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/img/Rust_Symbol_Flash.png"
                               ,git_ver             : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/version.txt"
                               ,ahk_rust_checker    : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/AHK_Rust_Drop_Checker.ahk"
                               ,update              : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/version.txt"
                               ,twitch_rewards      : "https://www.twitch.tv/drops/inventory"
                               ,kofi                : "https://ko-fi.com/0xb0bafe77"
                               ,patreon             : "https://www.patreon.com/0xB0BAFE77"
                               ,facepunch           : "https://twitch.facepunch.com/" }
    Static  rgx             := {profile_url         : "<\s*?a\s*?href=""(.*?)"""
                               ,avatar_url          : "img\s+src=""(.*?)""\s+alt="
                               ,username            : "class=""streamer-name"".*?>(.*?)</"
                               ,status              : "online-status.*?>(.*?)<"
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
    Static ghwnd            := {"notify_stream"     : ""
                               ,"notify_popup"      : ""
                               ,"notify_beep"       : ""
                               ,"notify_url"        : ""
                               ,"notify_url_edit"   : ""
                               ,"notify_icon"       : ""
                               ,"notify_file"       : ""
                               ,"gui_main"          : ""
                               ,"error_txt"         : ""
                               ,"user.status_pic"   : ""
                               ,"user.status_txt"   : ""
                               ,"user.snooze_btn"   : ""
                               ,"user.dismiss_btn"  : ""
                               ,"user.notify_cb"    : ""
                               ,"updater_gb"        : ""
                               ,"updater_btn"       : ""
                               ,"interval_sld"      : ""
                               ,"cps_txt"           : ""
                               ,"gui_splash"        : ""}
    
    Start()
    {
        this.splash.start("Starting up`n" this.title)
        
        ; Set shutdown processes
        this.splash.start("Setting`nShutdown`nFunctions")
        , OnExit(this.use_method(this, "shutdown"))
        
        ; Create program folders
        this.splash.update("Creating`nFolders")
        , this.folder_check() ? this.error(A_ThisFunc, "Folder's cannot be created.", 1) : ""
        
        ; Get fresh streamer data
        this.splash.update("Downloading`nStreamer Data")
        , this.get_streamer_data() ? this.error(A_ThisFunc, "Error getting streamer data.", 1) : ""
        
        ; Create streamer folders
        this.splash.update("Creating`nStreamer`nFolders")
        , this.create_streamer_paths() ? this.error(A_ThisFunc, "Streamer folders could not be created.", 1) : ""
        
        ; Load error log
        this.splash.update("Loading`nLog")
        , this.load_log() ? this.error(A_ThisFunc, "Unable to load error log.", 1) : ""
        
        ; Download images
        this.splash.update("Downloading`nImages")
        , this.download_images() ? this.error(A_ThisFunc, "Unable to download images.", 1) : ""
        
        ; Generate system tray
        this.splash.update("Creating`nFolders")
        , this.systray.create() ? this.error(A_ThisFunc, "The system tray could not be created.", 1) : ""
        
        ; Create and load notify_list settings
        this.splash.update("Generating`nNotify List")
        , this.generate_notify_list()
        
        ; Create gui
        this.splash.update("Creating`nGUI")
        , this.main_gui.create()
        
        ; Check for updates!
        this.splash.update("Update`nCheck!")
        , this.update_check(1)
        
        ; Show it
        this.main_gui.Show()
        
        ; Start heartbeat
        this.splash.update("Starting`nheartbeat.`n(CLEAR!!!)")
        , this.heartbeat()
        , this.splash.update("It's alive!")
        
        this.splash.finish()
        Return
    }
    
    heartbeat()
    {
        this.get_streamer_data()        ; Get fresh data
        , this.main_gui.update_gui()    ; Update GUI with new info
        , this.notify_check()           ; See if a notification needs to happen
        , this.next_beat()              ; Set when next update should occur
        Return
    }
    
    next_beat(time=0)
    {
        Static bf := ""
        (bf = "") ? bf := ObjBindMethod(this, "heartbeat") : ""
        time := (time = 0)  ? 1000 * 60 / this.interval : time * 1000
        SetTimer, % bf, Delete
        SetTimer, % bf, % -1 * Abs(time)
        Return
    }
    
    notify_check()
    {
        notify := 0
        For index, user in this.streamer_data                       ; Compare fresh data to old notify list
            If (user.status) && (this.notify_list[user.username])   ; 
                If (notify := this.notify_user(user))
                    Break 
        
        ; If not one was found, the flashing stops.
        If (notify = 0)
            this.systray.flash_stop := True
        
        Return
    }
    
    notify_user(user_data)
    {
        ; If stream
        GuiControlGet, state,, % this.main_gui.gHwnd.notify_stream
        (state) ? this.streamer_maintenance(user_data) : ""
        ; If popup
        GuiControlGet, state,, % this.main_gui.gHwnd.notify_popup
        (state) ? this.msg(user_data.username " is now online!!!") : ""
        ; If beep
        GuiControlGet, state,, % this.main_gui.gHwnd.notify_beep
        (state) ? this.play_beep() : ""
        ; If icon
        GuiControlGet, state,, % this.main_gui.gHwnd.notify_icon
        (state) ? this.systray.icon_flash() : ""
        ; If file
        GuiControlGet, state,, % this.main_gui.gHwnd.notify_file
        (state) ? this.write_to_file(user_data) : ""
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
        Static the_line := [] ; change this to the_line[] and always check the_line.1 as current user
        strm := this.live_stream
        TrayTip, title, % "user_data.username: " user_data.username "`nstrm.user: " strm.user "`nstrm.time: " strm.time "`nA_TickCount: " A_TickCount 
        
        ; Check if user needs t o be added to the line
        is_in_line := False
        For index, user in the_line
            If (is_in_line := (user_data.username = user.username))
                Break
        If !is_in_line
            the_line.Push(user_data)
        
        ; Check if there's an active streamer
        If !this.live_stream.active
            this.streamer_launch(the_line.1)
        Else If (the_line.1.username = this.live_stream.username)
        {
            time_running := this.readable_time(this.live_stream.time, A_TickCount)
            MsgBox, 0x4, Warning, % "Another stream was opened earlier and has not been running the required drop time."
                . "`nDo you still want to launch " user_data.username "'s page?"
                . "`n`nClick Yes to launch and No defer this uer until the current stream finishes."
            IfMsgBox, Yes
                this.kill_stream(strm.pid)
                , wait_list.InsertAt(1) := user_data
            Else wait_list.Push(user_data)
        }
        ;Else If (strm.username != the_line.1.username)
        
        ; If no one is streaming
        ;If (strm.active = 1)
        ;{
        ;    If ((A_TickCount - strm.time) < (user_data.drop_hours * hr_as_ms))
        ;        Return
        ;    GuiControl,, this.gHwnd[user_data.username].notify_cb, 0
        ;    this.kill_stream(strm.pid)
        ;}
        ;Else If 
        ;{
        ;    strm.active := True
        ;    , strm.pid  := this.open_url(user_data.profile_url)
        ;    , strm.time := A_TickCount
        ;    , strm.user := user_data.username
        ;}
        ;Else If (user_data.username != strm.user)
        ;{
        ;    Return
        ;}
        ;
        ;; Set Timer for being done.
        ;bf := ObjBindMethod(this, "kill_stream", strm.pid)
        ;SetTimer, % bf, -10000 ; % -1 * hr_as_ms * user_data.drop_hours
        Return
    }
    
    streamer_launch(user_data)
    {
        this.live_stream.active   := 1
        this.live_stream.username := user_data.username
        this.live_stream.pid      := this.open_url(user_data.profile_url)
        this.live_stream.time     := A_TickCount
        Return
    }

    
    get_notify_url()
    {
        GuiControlGet, url,, % this.gHwnd.notify_url_edit
        Return url
    }
    
    kill_stream(pid)
    {
        WinClose, % "ahk_pid " pid,, 1000
        Sleep, 500
        If WinExist("ahk_pid " pid)
            WinKill, % "ahk_pid " pid,, 1000
        Return
    }
    
    generate_notify_list()
    {
        this.notify_list := {}
        For index, user in this.streamer_data
            value := this.load_settings("notify_list", user.username)
            , this.notify_list[user.username] := (value = "Err" ? 0 : value)
        
        Return
    }
    
    get_streamer_data()
    {
        err := this.update_streamer_html()  ? -1  ; Get HTML or -1 if error
            :  this.parse_streamer_html()   ? -2  ; Parse HTML or -2 error
            :                                  0  ; Else 0 for success
        Return err
    }
    
    folder_check()
    {
        Status := 0
        For key, path in this.path
            If (path = "")
                Continue
            Else If !InStr(path, ".") && (FileExist(path) = "")
            {
                FileCreateDir, % path
                If ErrorLevel
                    this.error(A_ThisFunc, "Unable to create directory: " this.path[A_LoopField])
                    , status := 1
            }
        
        ; Check settings file
        If !FileExist(this.path.settings)
            FileAppend, % "[Settings]"
                . "`nCreated=" A_Now "`n`n"
                , % this.path.settings
        
        Return status
    }
    
    create_streamer_paths()
    {
        For index, user in this.streamer_data
            If !FileExist(this.path.streamers "\" user.username)
            {
                FileCreateDir, % this.path.streamers "\" user.username
                If ErrorLevel
                    this.error(A_ThisFunc, "Unable to create streamer directory: " this.path.app "\" user.username)
                    , status := 1
            }
        Return
    }
    
    load_log()
    {
        status := 0
        If (FileExist(this.path.log) = "")
        {
            FileAppend, % "Log file created: " A_Now "`n`n", % this.path.log
            If ErrorLevel
                this.error(A_ThisFunc, "No error log exists and could not create a new one.", 1)
                , status := 1
        }
        FileRead, err_log, % this.path.log
        this.err_log := err_log
        Return status
    }

    download_images()
    {
        Status := 0
        ; Make sure streamer data is there
        If !IsObject(this.streamer_data)
            Return -3
        
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
    
    ; Scrape HTML from streamer page
    ; Saves html to this.html
    ; Returns 1 = success, 0 = failure
    update_streamer_html()
    {
        this.html   := ""
        , status    := 0
        , web       := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        
        Try
            web.Open("GET", this.url.facepunch), web.Send()
        Catch
            this.error(A_ThisFunc, "Error getting data from site: " this.url.facepunch)
            , status := 1
        this.html := web.ResponseText
        
        Return status
    }
    
    ; rust_checker.streamer_data properties:
    ; .profile_url      URL to user's twitch or youtube profile (whichever was provided by the site)
    ; .avatar_url       URL to user's gaming avatar
    ; .avatar_loc       Location on disk where avatar is saved
    ; .username         User's username (Redudant, right?)
    ; .status           User's status of online or offline
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
        
        If (this.html = ""){
            this.error(A_ThisFunc, "No HTML to parse.")
            Return -4
        }
        
        Loop, Parse, % this.html, `n
            If (start = False)                                                                           ; Skip all unnecessary starting lines
            {
                InStr(A_LoopField, "STREAMER DROPS") ? start := true : ""                                ; Check if start is finished
                Continue
            }
            Else If InStr(A_LoopField, "general-drops")                                                  ; Break when the user drops are done
                Break
            Else  RegExMatch(A_LoopField, this.rgx.profile_url  , match) ? info := {profile_url:match1}  ; Start of new user. Get URL.
                : RegExMatch(A_LoopField, this.rgx.avatar_url   , match) ? info.avatar_url   := match1   ; Get avatar
                : RegExMatch(A_LoopField, this.rgx.username     , match) ? info.username     := match1   ; Get username
                : RegExMatch(A_LoopField, this.rgx.status       , match) ? info.status       := (match1
                                                                                            ="Live"?1:0) ; Get status
                : RegExMatch(A_LoopField, this.rgx.drop_pic_url , match) ? info.drop_pic_url := match1   ; Get URL for drop pic
                : RegExMatch(A_LoopField, this.rgx.drop_hrs     , match) ? info.drop_hours   := match1   ; Get pic name
                : RegExMatch(A_LoopField, this.rgx.drop_name    , match) ? info.drop_name    := match1   ; Get pic name
                : InStr(A_LoopField, "</a>")                             ? strm_list.Push(info)          ; End of user. Write info.
                : ""                                                                                     ; Else, do nothing
        
        For index, streamer in strm_list
            If InStr("account not found", streamer.username)
                strm_list[index].username := "Ban Pending"
            
        this.streamer_data := strm_list
        
        Return (this.streamer_data = "" ? 1 : 0)
    }
    
    img_getter(url, path, file_name, force:=0)
    {
        Status := 0
        If !FileExist(path)
        {
            FileCreateDir, % path
            (status := ErrorLevel)
                ? this.error(A_ThisFunc, "Save path does not exist and could not be created."
                    . "`npath: " path)
                : ""
        }
        
        If !FileExist(path "\" file_name) || (force = 1)
        {
            UrlDownloadToFile, % url, % path "\" file_name
            (status := ErrorLevel)
                ? this.error(A_ThisFunc, "Could not download file from url and save to location."
                    . "`nurl: " url "`nlocation: " path "\" file_name) : ""
        }
        
        Return status
    }
    
    use_method(obj, method, param:="")
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
    
    Class main_gui extends rust_checker
    {
        Static  gui_name        := "Main"
                , visible       := True
        
        create()
        {
            pad             := 10
            , padh          := pad/2
            , padq          := pad/4
            , pad2          := pad*2
            , gui_h         := 800
            , card_w        := 200
            , card_h        := 270
            , btn_w         := 90
            , btn_h         := 30
            , strm_total    := this.streamer_data.MaxIndex()
            , cards_per_col := (strm_total < 10) ? 3
                            : Ceil(strm_total/3)
            , opt_w         := 200
            , row_total     := Ceil(this.streamer_data.MaxIndex() / cards_per_col)
            , opt_h         := (row_total * card_h) + ((row_total-1) * pad)
            , gui_w         := opt_w + (cards_per_col * card_w) + (cards_per_col * pad)
            , err_gb_w      := gui_w/2 - pad*2
            , err_gb_h      := 40
            , err_txt_w     := err_gb_w - 2
            
            Gui, Main:New, +Caption -ToolWindow +HWNDhwnd, % this.title
                this.gHwnd.gui_main := hwnd
            Gui, Main:Default
            Gui, Margin, % pad, % pad
            Gui, Color, 0x000000, 0x222222
            Gui, Font, s12 cWhite
            
            ; Build options area first
            this.add_gui_options(pad, pad, opt_w, opt_h)
            
            ; Build streamer area next to it
            mx := 0
            For index, user in this.streamer_data
                (++mx > cards_per_col ? mx := 1 : "")
                , my := Ceil(A_Index/cards_per_col) 
                , x  := (card_w * (mx-1)) + (pad*mx) + opt_w
                , y  := (card_h * (my-1)) + (pad*my)
                , this.add_card(index, user, card_w, card_h, x, y)
            
            ; Add error area to display errors as they come
            Gui, Add, GroupBox, w%err_gb_w% h%err_gb_h% xm y+%pad% Section, Error Messages:
            Gui, Font, s8 cWhite
            Gui, Add, Edit, w%err_gb_w% xp yp+20 ReadOnly R1, FAKE ERROR MESSAGE FOR TESTING!
                this.gHwnd.error_txt
            
            ; Button Bank
            ; Add exit button
            x := cards_per_col * (card_w + pad) + opt_w - btn_w
            Gui, Font, s10
            Gui, Add, Button, w%btn_w% h%btn_h% x%x% y+-%btn_h% HWNDhwnd, Exit
                this.add_control_method(hwnd, this, "quit")
            ; Add hide button
            x := pad + btn_w
            Gui, Add, Button, w%btn_w% h%btn_h% xp-%x% yp HWNDhwnd, Hide
                this.add_control_method(hwnd, this, "hide")
            ; Add Uncheck all button
            x := pad + btn_w
            Gui, Add, Button, w%btn_w% h%btn_h% xp-%x% yp HWNDhwnd, Uncheck All
                this.add_control_method(hwnd, this, "check_all", 0)
            ; Add check all button
            x := pad + btn_w
            Gui, Add, Button, w%btn_w% h%btn_h% xp-%x% yp HWNDhwnd, Check All
                this.add_control_method(hwnd, this, "check_all", 1)
            
            ; Add overlay button
            x := (pad2 + btn_w)
            Gui, Add, Button, w%btn_w% h%btn_h% xp-%x% yp HWNDhwnd, Overlay
                this.add_control_method(hwnd, this.overlay, "show")
            
            ; Allows the gui to be clicked and dragged
            bf := ObjBindMethod(this, "WM_LBUTTONDOWN", A_Gui)
            OnMessage(0x201, bf)
            bf := ObjBindMethod(this, "WM_EXITSIZEMOVE", A_Gui)
            OnMessage(0x232, bf)
            bf := ObjBindMethod(this, "WM_CLOSE", A_Gui)
            OnMessage(0x10, bf)
            
            Return
        }
        
        add_card(index, user, sw, sh, sx, sy)
        {
            pad             := 10
            , pad2          := pad*2
            , padh          := pad/2
            , padq          := pad/4
            , status_w      := 70
            , status_h      := 20
            , avatar_w      := 50
            , avatar_h      := 50
            , drop_pic_w    := sw - pad
            , drop_pic_h    := drop_pic_w
            , notify_cb_w   := sw/2
            , notify_cb_h   := 20
            , action_btn_w  := (drop_pic_w - avatar_w - pad2) / 2
            , action_btn_h  := avatar_h - notify_cb_h - pad
            , name          := user.username
            , this.gHwnd[name] := {}
            
            Gui, Main:Default
            Gui, Font, S12 Bold q5 cWhite
            ; Create groupbox border and add username to groupbox
            Gui, Add, GroupBox, w%sw% h%sh% x%sx% y%sy%, % name
            
            ; Add status background to groupbox border
            x := sw - status_w - padh
            Gui, Add, Picture, w%status_w% h%status_h% xp+%x% yp HWNDhwnd, % this.path["img_" (user.status ? "online" : "offline")]
                this.gHwnd[name].status_pic := hwnd
            ; Add status text
            Gui, Font, S10 Bold q5 cBlack
            Gui, Add, Text, w%status_w% h%status_h% xp yp+2 +Center HWNDhwnd
                , % user.status ? "LIVE" : "OFFLINE"
                this.transparent_bg(hwnd)
                this.gHwnd[name].status_txt := hwnd
            
            ; Drop_pic image
            x := sx + padh
            Gui, Add, Picture, w%drop_pic_w% h%drop_pic_h% x%x% yp+20 +Border, % user.drop_pic_loc
            ; Drop_name description
            h := 30
            Gui, Font, S10 Norm q5 cWhite
            Gui, Add, Text, wp h%h% xp y+-%h% HWNDhwnd +Center +Border +0x200, % user.drop_name
            
            ; User's icon
            Gui, Add, Picture, w%avatar_w% h%avatar_h% xp y+0 +Border +Section, % user.avatar_loc
            ; Add snooze/dismiss buttons
            Gui, Add, Button, w%action_btn_w% h%action_btn_h% x+%padh% yp+%padh% +HWNDhwnd, Snooze
                this.gHwnd[name].snooze_btn := hwnd
            Gui, Add, Button, w%action_btn_w% h%action_btn_h% x+%pad% yp +HWNDhwnd, Dismiss
                this.gHwnd[name].dismiss_btn := hwnd
            
            ; Add notify checkbox
            Gui, Font, S10 Bold q5
            w := sw - avatar_w - pad2
            y := notify_cb_h
            x := avatar_w + pad
            Gui, Add, Checkbox, w%w% h%notify_cb_h% xs+%x% y+%padh% +HWNDhwnd, Notify Me!
                this.gHwnd[name].notify_cb := hwnd
                this.add_control_method(hwnd, this, "notify_action", name)
                GuiControl,, % hwnd, % this.notify_list[name]
            ; Hide the buttons until they're needed
            GuiControl, Hide, % this.gHwnd[name].snooze_btn
            GuiControl, Hide, % this.gHwnd[name].dismiss_btn
            
            ; Add "notify me" checkbox below group box
            ;Gui, Add, Checkbox, 
            ;MsgBox, % "Gui card check!`n" "status_w: " status_w "`nstatus_h: " status_h "`navatar_w: " avatar_w "`navatar_h: " avatar_h "`ndrop_pic_w: " drop_pic_w "`ndrop_pic_h: " drop_pic_h "`nsw: " sw "`nsh: " sh "`nsx: " sx "`nsy: " sy 
            Return
        }
        
        add_gui_options(start_x, start_y, max_w, max_h)
        {
            ; Standard
            pad         := 10
            , pad2      := pad * 2
            , pad3      := pad * 3
            , padh      := pad / 2
            , pad_gb    := pad * 2.5
            , pad_ul    := pad_gb + pad
            , x_left    := start_x + pad
            , gb_w      := max_w - pad
            , font_gb   := "s12 Norm Bold cWhite"
            , font_link := "s10 Norm Underline c00A2ED"
            , font_def  := "s10 Norm cWhite"
            
            ; Updater section
              upd_btn_w := gb_w - pad2
            , upd_btn_h := 30
            , upd_gb_h  := upd_btn_h + pad_ul
            Gui, Font, % font_gb
            Gui, Add, GroupBox, w%gb_w% h%upd_gb_h% x%start_x% y%start_y% Section +HWNDhwnd, Update Checker:
                this.ghwnd.updater_gb := hwnd
                last_gb := upd_gb_h
            Gui, Font, Norm cBlack
            Gui, Add, Button, w%upd_btn_w% h%upd_btn_h% xp+%pad% yp+%pad_gb% +HWNDhwnd +Disabled, Initializing...
                this.gHwnd.updater_btn := hwnd
                this.start_update_check_timer()
                this.add_control_method(hwnd, this, "run_update")
            
            ; Refresh Frequency
            slide_min   := 1
            , slide_max := 10
            , ref_def_h := 20
            , ref_bud_w := 15
            , ref_sld_w := gb_w - (ref_bud_w*2) - pad2
            , ref_txt_w := gb_w - pad2
            , ref_gb_h  := ref_def_h*2 + pad_ul
            y := last_gb + pad
            Gui, Font, % font_gb
            Gui, Add, GroupBox, w%gb_w% h%ref_gb_h% xs ys+%y% Section, Check Frequency:
                last_gb := ref_gb_h
            Gui, Font, % font_def
            Gui, Add, Text, w%ref_bud_w% h%ref_def_h% xs+%pad% yp+%pad_gb% +Center, 1
            Gui, Add, Slider, w%ref_sld_w% h%ref_def_h% x+0 yp range%slide_min%-%slide_max% +HWNDhwnd Line1 ToolTip TickInterval AltSubmit
                , % this.load_interval()
                this.gHwnd.interval_sld := hwnd
                this.add_control_method(hwnd, this, "update_interval")
                this.update_interval(hwnd,"","")
            Gui, Add, Text, w%ref_bud_w% h%ref_def_h% x+0 yp +Center, 10
            Gui, Add, Text, w%ref_txt_w% h%ref_def_h% xs+%pad% y+%padh% +Center +HWNDhwnd, Initializing...
                this.gHwnd.cps_txt := hwnd
                this.update_interval_per_sec()
            
            ; Quick link to twitch rewards claim page
            link_list   := [{txt:"Twitch Rewards Page"  , url:this.url.twitch_rewards   }
                           ,{txt:"Streamer Drops Page"  , url:this.url.facepunch        }
                           ,{txt:"AHK Drop Alert Home"  , url:this.url.git_homepage     } ]
            , ql_txt_w  := gb_w - pad2
            , ql_txt_h  := 16
            , ql_gb_h  := ((ql_txt_h + padh) * link_list.MaxIndex()) + pad_ul - padh
            y := last_gb + pad
            Gui, Font, % font_gb
            Gui, Add, Groupbox, w%gb_w% h%ql_gb_h% xs ys+%y% +HWNDhwnd Section, Quick Links:
                last_gb := ql_gb_h
            Gui, Font, % font_link, Consolas
            For index, data in link_list
            {
                y := (index = 1 ? pad_gb : (ql_txt_h+padh))
                Gui, Add, Text, w%ql_txt_w% h%ql_txt_h% xs+%pad% yp+%y% +HWNDhwnd, % data.txt
                this.add_control_method(hwnd, this, "open_url", data.url)
            }
            Gui, Font
            
            ; Notify Options
            noti_cb_w   := gb_w - pad2
            , noti_cb_h := 16
            , noti_edt_h:= 20
            , noti_gb_h := (this.notify_opt.MaxIndex() * (noti_cb_h + padh)) + pad_ul - padh
            y := last_gb + pad
            Gui, Font, % font_gb
            Gui, Add, Groupbox, w%gb_w% h%noti_gb_h% xs ys+%y% +HWNDhwnd Section, Notify Options:
                last_gb := noti_gb_h
            Gui, Font, % font_def
            For index, data in this.notify_opt
            {
                Gui, Add, Checkbox, % "w" noti_cb_w " h" noti_cb_h " xs+" pad " " (index = 1 ? " ys+" pad_gb : " y+" padh) " +HWNDhwnd", % data.txt
                    this.gHwnd["notify_" data.type] := hwnd
                    value := this.load_settings("notify_pref", data.type)
                    GuiControl,, % hwnd, % (value = "err" ? data.def : value)
                    this.add_control_method(hwnd, this, "notify_update", data.type, hwnd)
                    this.notify_update(data.type, hwnd)
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
            
            ;~ opt_list := [{txt:"Opacity_Slider"    ,type:"Slider"   ,opt:"" ,}
                        ;~ ,{txt:"Box_Width_Edit"    ,type:"Edit"     ,opt:"" ,}
                        ;~ ,{txt:"Box_Height_Edit"   ,type:"Edit"     ,opt:"" ,}
                        ;~ ,{txt:"Columns"           ,type:"Slider"   ,opt:"" ,}
                        ;~ ,{txt:"Lock"              ,type:"Checkbox" ,opt:"" ,}
                        ;~ ,{txt:"Color: Background" ,type:"Pic"      ,opt:"" ,,color:"black"  }
                        ;~ ,{txt:"Color: Online"     ,type:"Pic"      ,opt:"" ,,color:"green"  }
                        ;~ ,{txt:"Color: Offline"    ,type:"Pic"      ,opt:"" ,,color:"red"    }
                        ;~ ,{txt:"Color: Flash"      ,type:"Pic"      ,opt:"" ,,color:"fuschia"} ]
            
            opt_list := [{txt:"Opacity" ,type:"Slider"      ,opt:"", rangel:1, rangeh:this.streamer_data.MaxIndex()}
                        ,{txt:"Columns" ,type:"Slider"      ,opt:"", rangel:1, rangeh:100}
                        ,{txt:"Lock"    ,type:"Checkbox"    ,opt:""}]
            txt_h       := 16
            txt_w       := gb_w - pad2
            buddy_h     := 20
            buddy_w     := 15
            cb_h        := 16
            cb_w        := gb_w - pad2
            slider_h    := 20
            slider_w    := gb_w - (buddy_w*2) - pad
            ovr_gb_h    := (3*txt_h) + (2*slider_h) + (pad*5) + pad_ul
            y := last_gb + pad
            Gui, Font, % font_gb
            Gui, Add, Groupbox, w%gb_w% h%ovr_gb_h% xs ys+%y% +HWNDhwnd Section, Overlay Settings:
                last_gb := ovr_gb_h
            Gui, Font, % font_def
            Gui, Add, Checkbox, w%cb_w% h%cb_h% xs+%pad% ys+%pad_gb%, Click-Through (Lock)
            
            ; Donations quick links
            link_list   := [{txt:"Ko-Fi Donation"   , url:this.url.patreon  }
                           ,{txt:"Patreon Donation" , url:this.url.kofi     } ]
            , ql_txt_w  := gb_w - pad2
            , ql_txt_h  := 16
            , ql_gb_h  := (ql_txt_h + padh) * link_list.MaxIndex() + pad_ul
            y := max_h - ql_gb_h + pad
            Gui, Font, % font_gb
            Gui, Add, Groupbox, w%gb_w% h%ql_gb_h% xs y%y% +HWNDhwnd Section, Donate:
                last_gb := ql_gb_h
            Gui, Font, % font_link, Consolas
            For index, data in link_list
            {
                y := (index = 1 ? " ys+" pad_gb : " y+" padh)
                ;y := (index = 1 ? pad_gb : (ql_txt_h+padh))
                Gui, Add, Text, w%ql_txt_w% h%ql_txt_h% xs+%pad% %y% +HWNDhwnd, % data.txt
                this.add_control_method(hwnd, this, "open_url", data.url)
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
        
        check_all(state)
        {
            For index, user in this.streamer_data
                GuiControl,, % this.ghwnd[user.username].notify_cb, % state
            Return
        }
        
        notify_update(type, hwnd)
        {
            GuiControlGet, state,, % hwnd
            this.save_settings("notify_pref", type, state)  ; Save to settins file
            If (type = "file"){
                
            }
            Return
        }
        
        load_interval()
        {
            i := this.load_settings("main_gui", "interval")
            Return (i = "Err")  ? 6
                :  (i < 1)      ? 1
                :  (i > 10)     ? 10
                :                 i
        }
        
        update_interval_per_sec()
        {
            GuiControl, , % this.gHwnd.cps_txt
                , % "Checking every " Round(60 / this.interval) " seconds" 
            Return 
        }
        
        start_update_check_timer()
        {
            bf  := ObjBindMethod(this, "update_check")
            SetTimer, % bf, % Abs(this.update_freq) * -1000
            Return
        }
        
        update_interval(hwnd)
        {
            GuiControlGet, interval,, % hwnd
            this.interval := interval
            this.update_interval_per_sec()
            this.next_beat(1)
            Return
        }
        
        notify_action(name, hwnd, GuiEvent, EventInfo, ErrLevel:="")
        {
            GuiControlGet, state, , % hwnd                  ; Get check state
            this.notify_list[name] := state                 ; Update state into notify list
            this.save_settings("notify_list", name, state)  ; Save to settins file
            this.heartbeat()                                ; Do a check
            Return
        }
        
        update_gui()
        {
            txt := ""
            For index, user in this.streamer_data
            {
                ; Get current text
                GuiControlGet, txt,, % this.gHwnd[user.username].status_txt
                
                ; Don't update if status hasn't changed
                If ((txt = "live") && (user.status))
                    Continue
                Else If ((txt = "offline") && !user.status)
                    Continue
                Else
                {
                    id      := this.gHwnd[user.username].status_pic
                    path    := (user.status ? "img_online" : "img_offline")
                    
                    GuiControl,, % id, % this.path[path]
                    GuiControl,, % this.gHwnd[user.username].status_txt
                        , % (user.status ? "LIVE" : "OFFLINE")
                }
            }
            Return
        }
        
        transparent_bg(hwnd)
        {
            GuiControl, +BackgroundTrans, % hwnd
            Return
        }
        
        WM_LBUTTONDOWN()
        {
            If (A_Gui = "Main")
            {
                MouseGetPos,,,, con
                If !InStr(con, "button") && !InStr(con, "trackbar321") && !InStr(con, "edit")
                    SendMessage, 0x00A1, 2,,, A
            }
            Return
        }
        
        WM_EXITSIZEMOVE()
        {
            this.save_last_xy()
            Return
        }
        
        load_last_xy()
        {
            this.last_x := this.load_settings("main_gui", "last_x")
            this.last_y := this.load_settings("main_gui", "last_y")
            Return
        }
        
        update_last_xy()
        {
            WinGetPos, x, y,,, % "ahk_id " this.gHwnd.gui_main
            this.last_x := x
            , this.last_y := y
            Return
        }
        
        save_last_xy()
        {
            this.update_last_xy()
            (this.last_x*0 = 0) ? this.save_settings("main_gui", "last_x", this.last_x) : ""
            (this.last_y*0 = 0) ? this.save_settings("main_gui", "last_y", this.last_y) : ""
            Return
        }
        
        Show()
        {
            this.load_last_xy()
            (this.last_x*0 = 0 ? "" : this.last_x := 0)
            (this.last_y*0 = 0 ? "" : this.last_y := 0)
            Gui, Main:Show, % "AutoSize x" this.last_x " y" this.last_y, % this.gui_name ;Center, % this.title
            this.visible := True
            this.systray.update_tray_show_hide()
        }
        
        Hide()
        {
            this.save_last_xy()
            Gui, Main:Hide
            this.visible := False
            this.systray.update_tray_show_hide()
        }
        
        Toggle()
        {
            this.visible
                ? this.Hide() 
                : this.Show()
        }
    }
    
    Class splash extends rust_checker
    {
        Static  font_opt   := "s20 Bold "
        start(msg)
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
            , this.get_monitor_workarea(scrn_t, scrn_r, scrn_b, scrn_l)
            , this.img_getter(this.url.img_rust_symbol, this.path.img, "img_rust_symbol.png")
            
            Gui, splash:New, -Caption +HWNDhwnd +Border +ToolWindow +AlwaysOnTop
                this.gHwnd.gui_splash := hwnd
            Gui, splash:Default
            Gui, Margin, 0, 0
            Gui, Color, 0x000001
            
            Gui, Add, Picture, w%gui_w% h%gui_h% x0 y0, % this.path.img_rust_symbol
            Gui, Font, % "s20 cBlack Bold", Consolas
            Gui, Add, Text, w%txt_w% h%txt_h% x%pad% y%pad% +HWNDhwnd +Center +BackgroundTrans, % "`n" msg
                this.gHwnd.spalsh_txt_shadow := hwnd
            Gui, Font, % "s20 cWhite Norm", Consolas
            Gui, Add, Text, w%txt_w% h%txt_h% x%padO% y%padO% +HWNDhwnd +Center +BackgroundTrans, % "`n" msg
                this.gHwnd.splash_txt := hwnd
            x := scrn_r - scrn_l - gui_w
            y := scrn_b - scrn_t - gui_h
            Gui, Show, w%gui_w% h%gui_h% x%x% y%y%
            this.animate()
            Return
        }
        
        update(txt)
        {
            Gui, Splash:Default
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
            Gui, splash:Destroy
        }
    }
    
    ; Show/Hide Gui (default)
    ; Overlay Control
    ; Links
    ; ---
    ; Exit
    ; Donate
    Class systray extends rust_checker
    {
        Static flash_stop := 0
        
        create()
        {
            Menu, Tray, NoStandard                              ; Clean slate
            this.icon_reset()
            
            bf := ObjBindMethod(this.main_gui, "toggle")
            Menu, Tray, Add, Show, % bf                         ; Show/hide option
            Menu, Tray, Default, 1&                             ; Set show/hide to default
            
            Menu, Tray, Add                                     ; DIVIDER for links
            bf := ObjBindMethod(this, "open_url", this.url.twitch_rewards)
            Menu, Tray, Add, Drop Reward Claim Page, % bf       ; Rewards page
            bf := ObjBindMethod(this, "open_url", this.url.facepunch)
            Menu, Tray, Add, Facepunch Twitch Page, % bf        ; Rust update/blog page
            bf := ObjBindMethod(this, "open_url", this.url.facepunch_blog)
            Menu, Tray, Add, Facepunch Twitch Page, % bf        ; Facepunch home page
            bf := ObjBindMethod(this, "open_url", this.url.git_homepage)
            Menu, Tray, Add, Github Home Page, % bf             ; Github Repo
            bf := ObjBindMethod(this, "open_url", this.url.git_homepage)
            Menu, Tray, Add, Donate, % bf                       ; Donation link
            
            Menu, Tray, Add
            bf := ObjBindMethod(this, "quit")
            Menu, Tray, Add, Exit, % bf                         ; Exit option
            Return
        }
        
        icon_reset()
        {
            Menu, Tray, Icon, % this.path.img_rust_symbol     ; Set Icon
        }
        
        update_tray_show_hide()
        {
            Menu, Tray, Rename, 1&, % (this.main_gui.visible ? "Hide" : "Show")
            Return
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
            Menu, Tray, Icon, % this.path["img_rust_symbol" (toggle ? "" : "_2")]
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
    
    Class overlay extends rust_checker
    {
        Static  visible := False
        create()
        {
            this.ghwnd.overlay := {}
            
            Gui, overlay:New, -Caption -ToolWindow +HWNDhwnd
            
            Return
        }
      
        Show()
        {
            MsgBox, Overlay not implemented yet.
            ;Gui, overlay:Show
            Return
        }
        Hide()
        {
            Gui, overlay:Hide
            Return
        }
    }
    
    add_control_method(hwnd, object_name, method_name, params*)
    {
        bf := ObjBindMethod(object_name, method_name, params*)
        GuiControl, +g, % hwnd, % bf
        Return
    }
    
    ; Get the non-reserved area of a screen
    get_monitor_workarea(ByRef mTop, ByRef mRight, ByRef mBottom, ByRef mLeft, m_num:=0)
    {
        If (m_num = 0)
            SysGet, m_num, MonitorPrimary
        SysGet, m, MonitorWorkArea, % m_num
        Return
    }
    
    shutdown()
    {
        this.save_log()                             ; Save error logs
        this.main_gui.save_last_xy()                ; Save last coords
        this.save_settings("main_gui", "interval"   ; Save frequency of checking
            , this.main_gui.interval)
        
        ; MsgBox, 0x4, Cleanup, Delete downloaded images and other files?
        ; IfMsgBox, Yes
        ;     FileRemoveDir, % this.path.app, 1
        Return
    }
    
    quit()
    {
        MsgBox, 0x4, Exiting, Close program?
        IfMsgBox, Yes
            ExitApp
        Return
    }
    
    update_check(verbose := 0)
    {
        online_version  := Trim(this.web_get(this.url.update), " `t`r`n")
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
            }
        
        Gui, Main:Default
        ; Set the Updater Groupbox text and color
        GuiControl, % "+c" (update_found ? "FF0000" : "00FF00"), % this.main_gui.gHwnd.updater_gb
        ; Set the button text
        Gui, Font, Norm cBlack
        GuiControl, Text, % this.main_gui.gHwnd.updater_btn, % (update_found ? "Update Available!" : "Up To Date!")
        ; Enable/disable
        GuiControl, % (update_found ? "Enable" : "Disable"), % this.main_gui.gHwnd.updater_btn
        Return
    }
    
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
        
        ;code := "#SingleInstance Force`nMsgBox, % ""Destination: "" A_Args.1 ""``nSource: "" A_Args.2`nSleep, 3000`nExitApp"
        code := "#SingleInstance Force"
            . "`nFileMove, % A_Args.1, % A_Args.2, 1"
            . "`nRun, % A_AhkPath A_Space A_Args.2"
            . "`nExitApp"
        source      := dq temp_path "\" file_name dq
        destination := dq A_ScriptFullPath dq
        ; Delete any previous updater
        If FileExist(temp_path "\" upd_name)
            FileDelete, % temp_path "\" upd_name
        FileAppend, % code, % temp_path "\" upd_name
        (status := ErrorLevel)
            ? this.error(A_ThisFunc, "Could not write updater file."
                . "`nlocation: " temp_path "\" upd_name) : ""
        ; Run updater and exit here
        Run, % A_AhkPath " " temp_path "\" upd_name
            . " " source
            . " " destination
        ExitApp
    }
    
    web_get(url)
    {
        web := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        Try
            web.Open("GET", url), web.Send()
        Catch
        {
            this.error(A_ThisFunc, "Error getting data from site: " url)
            Return "Err"
        }
        Return web.ResponseText
    }
    
    play_beep()
    {
        Static running := False
        If running
            Return
        running := True
        num := -1
        Loop, 5
        {
            SoundPlay, % "*" 16
        }
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
    
    readable_time(ms_in_1, ms_in_2 := "")
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
    
    msg(msg, opt:=0x0)
    {
        MsgBox, % opt, % this.title, % msg
    }
    
    error(call:="func here", msg:="msg here", option:=0)
    {
        this.err_last   := A_Now "`nCall: " call "`nMessage: " msg
        this.err_log    .= this.err_last "`n`n"
        MsgBox, % this.err_last
        
        If (option = -1)
            ExitApp
        If (option = 1)
        {
            MsgBox, 0x4, Error, Do you want to reload the script and try again?
            IfMsgBox, Yes
                Reload
        }
        
        Return 0
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

Will this auto-log into my account and save my passwords?
Nope. The script is open source and there's no good way to securely store your password. Thus, all logging in/out has to be done by the user.  
Plus, this protects me because no one can be like "Your program let me info out!" Pfft. No, it didn't.

Is this going to log my password/keystrokes?  
No... It's an open source program. You can look at the code. The only data transmission going on is to the facepunch servers to get up-to-date HTML and to GitHub to get files like images. No other send/get requests are sent.  
If you're still doubtful, don't use it. I R N0T tRY1Ng 2 HAX0R UR .nfo Â¯\_(-_-)_/Â¯  
The purpose of this is to help the community get skins.  

Can I set it to automatically open up the streamer when they come on?  
Yes. It's one of the "notification" options. But it's the user's responsibility to be logged into twitch and to have their accounts linked. There are instructions about this at script launch.  
You can watch other twitch streams, but do not be logged into your account while doing so or it could affect you getting drops.

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
