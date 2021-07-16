#SingleInstance Force
#Warn
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
; On load > make gui
;   Gui should have a close button and minimize button
; Scrape https://twitch.facepunch.com/ to see if 
;   Check for keywords online offline'
; If scrape returns successful, populate gui with people
;   + Set timer to continuously check the site every X amount of seconds
*/

/*
user.username    
user.profile_url
user.avatar_url  
user.status      
user.drop_name   
user.drop_pic_url
*/

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
    Static  streamer_data   := ""
            , title         := "AHK Rust Drop Checker"
            , version       := "1.0.0.1"
            , html          := ""
            , err_last      := ""
            , err_log       := ""
            , checker       := True
            , notify_list   := {}
            , update_freq   := 60
    Static  path            := {app             : A_AppData "\AHK_Rust_Drops"
                               ,img             : A_AppData "\AHK_Rust_Drops\img"
                               ,temp            : A_AppData "\AHK_Rust_Drops\temp"
                               ,streamers       : A_AppData "\AHK_Rust_Drops\streamers"
                               ,log             : A_AppData "\AHK_Rust_Drops\log.txt"
                               ,settings        : A_AppData "\AHK_Rust_Drops\settings.ini"
                               ,rust_icon       : A_AppData "\AHK_Rust_Drops\img\Rust_Symbol.png"
                               ,img_online      : A_AppData "\AHK_Rust_Drops\img\Online.png"
                               ,img_offline     : A_AppData "\AHK_Rust_Drops\img\Offline.png" }
    Static  url             := {git_img_online  : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/img/Online%20Blank%203D.png"
                               ,git_img_offline : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/img/Offline%20Blank%203D.png"
                               ,git_img_symbol  : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/img/Rust_Symbol.png"
                               ,git_ver         : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/version.txt"
                               ,ahk_rust_checker: "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/AHK_Rust_Drop_Checker.ahk"
                               ,update          : "https://raw.githubusercontent.com/0xB0BAFE77/AHK_Rust_Drop/main/version.txt"
                               ,twitch_rewards  : "https://www.twitch.tv/drops/inventory"
                               ,facepunch       : "https://twitch.facepunch.com/" }
    Static  rgx             := {profile_url     : "<\s*?a\s*?href=""(.*?)"""
                               ,avatar_url      : "img\s+src=""(.*?)""\s+alt="
                               ,username        : "class=""streamer-name"".*?>(.*?)</"
                               ,status          : "online-status.*?>(.*?)<"
                               ,ext             : "\.(\w+)\s*?$"
                               ,drop_pic_url    : "img\s*?src=""(.*?)"".*?title="
                               ,drop_name       : "class=""drop-name"".*?>(.*?)</" }
    
    Start()
    {
        this.splash.start("Starting up`n" this.title)
        OnExit(this.use_method(this, "shutdown"))
        
        ; Create program folders
        this.splash.update("Creating`nFolders")
        , this.folder_check() ? this.error(A_ThisFunc, "Folder's cannot be created.", 1) : ""
        
        
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
        
        ; Create and load notify_list settings
        this.splash.update("Generating`nNotify List")
        , this.generate_notify_list()
        
        ; Create gui
        this.splash.update("Creating`nGUI")
        , this.main_gui.create()
        
        ; Start heartbeat
        this.splash.update("Starting`nheartbeat.`n(CLEAR!!!)")
        , this.heartbeat()
        , this.splash.update("It's alive!")
        
        ; Check for updates!
        this.splash.update("Update`nCheck!")
        , this.update_check(1)
        
        this.splash.finish()
        this.main_gui.Show()
        Return
    }
    
    heartbeat()
    {
        this.next_beat()                ; Set when next update should occur
        , this.get_streamer_data()      ; Get fresh data
        , this.main_gui.update_gui()    ; Update GUI with new info
        , this.notify_check()           ; See if a notification needs to happen
        Return
    }
    
    next_beat(time:=0)
    {
        Static bf := ""
        (bf = "")   ? bf := ObjBindMethod(this, "heartbeat") : ""
        (time = 0)  ? time := 1000 * 60 / this.main_gui.interval : ""
        SetTimer, % bf, Delete
        SetTimer, % bf, % -1 * Abs(time)
        Return
    }
    
    notify_check()
    {
        For index, user in this.streamer_data                       ; Compare fresh data to old notify list
        {
            If (user.status) && (this.notify_list[user.username])   ; 
                this.notify_user(user.username)
        }
        ; UPdate notify list
    }
    
    notify_user(name)
    {
        TrayTip, Online!, %name% is online! Make the icon flash!, 3
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
            If !InStr(path, ".") && (FileExist(path) = "")
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
            If !FileExist(this.path.app "\" user.username)
            {
                FileCreateDir, % this.path.app "\" user.username
                If ErrorLevel
                    this.error(A_ThisFunc, "Unable to create streamer directory: " this.path.app "\" user.username)
                    , status := 1
            }
        Return
    }
    
    load_log()
    {
        status := 0
        FileRead, err_log, % this.path.log
        If ErrorLevel
        {
            FileAppend, % (err_log := "Log file created: " A_Now "`n`n"), this.path.log
            If ErrorLevel
                this.error(A_ThisFunc, "No error log exists and could not create a new one.", 1)
                , status := 1
        }
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
        
        ; Get status online/offline icons
        (this.img_getter(this.url.git_img_online, this.path.img, "Online.png")  = 1)    ? status := 1 : ""
        (this.img_getter(this.url.git_img_offline, this.path.img, "Offline.png")  = 1)  ? status := 1 : ""
        
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
                : RegExMatch(A_LoopField, this.rgx.drop_name    , match) ? info.drop_name    := match1   ; Get pic name
                : InStr(A_LoopField, "</a>")                             ? strm_list.Push(info)          ; End of user. Write info.
                : ""                                                                                     ; Else, do nothing
        
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
        ; gHwnd properties:
        ; gui               
        ; error_txt
        Static  gHwnd           := {}
                , gui_name      := "Main"
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
            , btn_w         := 80
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
            
            
            (this.img_getter(this.url.git_img_offline , this.path.img, "Rust_Symbol.png") = 1)
                ? status := 1 : ""
            
            Gui, Main:New, +Caption +HWNDhwnd, Rust Streamer Checker
                this.gHwnd[this.gui_name] := hwnd
            Gui, Main:Default
            Gui, Margin, % pad, % pad
            Gui, Color, 0x000000, 0xFFFF00
            Gui, Font, s12 cWhite
            
            ; Possible auto-mode later
            ; Gui, Add, Checkbox, xm ym, Auto-Mode
            
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
            
            ; Add exit and min button
            x := cards_per_col * (card_w + pad) + opt_w - btn_w
            Gui, Add, Button, w%btn_w% h%btn_h% x%x% y+-%btn_h% HWNDhwnd, Exit
                this.add_control_method(hwnd, this, "quit")
            ; Minimize button
            x := card_w + pad + btn_w
            Gui, Font, s10
            Gui, Add, Button, w%btn_w% h%btn_h% x+-%x% yp HWNDhwnd, Minimize
            
            ; Clean up button
            ;Gui, Add, Button, w%btn_w% h%btn_h% x+%pad2% yp HWNDhwnd, Clean Up
            ; Allows the gui to be clicked and dragged
            bf := ObjBindMethod(this, "WM_LBUTTONDOWN", A_Gui)
            OnMessage(0x0201, bf)
            bf := ObjBindMethod(this, "WM_EXITSIZEMOVE", A_Gui)
            OnMessage(0x0232, bf)
            
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
            Gui, Add, Picture, w%status_w% h%status_h% xp+%x% yp HWNDhwnd
                , % this.path[(user.status ? "img_online" : "img_offline")]
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
        
        ;gHwnd.udpater_btn
        ;gHwnd.update_txt
        ;gHwnd.interval_sld
        ;gHwnd.
        ;gHwnd.
        add_gui_options(start_x, start_y, max_w, max_h:=0)
        {
            pad         := 10
            , pad2      := pad * 2
            , pad3      := pad * 3
            , padh      := pad / 2
            , x_left    := start_x + pad
            , gb_w      := max_w - pad
            
            , upd_gb_h  := 60
            , upd_btn_w := gb_w - pad2
            , upd_btn_h := upd_gb_h - pad3
            
            , slide_min := 1
            , slide_max := 10
            , ref_def_h := 20
            , ref_bud_w := 15
            , ref_sld_w := gb_w - (ref_bud_w*2) - pad2
            , ref_txt_w := gb_w - pad2
            , ref_gb_h  := ref_def_h * 2 + (pad2*2)
            
            Gui, Font, s12 Bold cFFAA00
            Gui, Add, GroupBox, w%gb_w% h%upd_gb_h% x%start_x% y%start_y% Section +HWNDhwnd, Update Checker
                this.ghwnd.updater_gb := hwnd
            Gui, Font, s10 Norm cBlack
            Gui, Add, Button, w%upd_btn_w% h%upd_btn_h% xp+%pad% yp+%pad2% +HWNDhwnd +Disabled, Initializing...
                this.gHwnd.updater_btn := hwnd
                this.start_update_check_timer()
                this.add_control_method(hwnd, this, "run_update")
            ;;;;;;;;;;;;; I"m here ;;;;;;;;;;;;;
            ; Refresh frequency
            y := upd_gb_h + pad
            Gui, Font, cWhite
            Gui, Add, GroupBox, w%gb_w% h%ref_gb_h% xs ys+%y% Section, Streamer Check Frequency
            Gui, Font, s10 Norm
            Gui, Add, Text, w%ref_bud_w% h%ref_def_h% xs+%pad% yp+%pad2% +Center, 1
            Gui, Add, Slider, w%ref_sld_w% h%ref_def_h% x+0 yp range%slide_min%-%slide_max% +HWNDhwnd Line1 ToolTip TickInterval AltSubmit
                , % this.load_interval()
                this.gHwnd.interval_sld := hwnd
                this.add_control_method(hwnd, this, "update_interval")
                this.update_interval(hwnd,"","")
            
            Gui, Add, Text, w%ref_bud_w% h%ref_def_h% x+0 yp +Center, 10
            Gui, Add, Text, w%ref_txt_w% h%ref_def_h% xs+%pad% y+%pad% +Center +HWNDhwnd, Initializing...
                this.gHwnd.check_per_sec := hwnd
                this.update_interval_per_sec()
            
            ;~ ; Quick link to twitch rewards claim page
            ;~ y := upd_gb_h + pad
            ;~ Gui, Font, s10 Underline c00A2ED
            ;~ Gui, Add, Text, w%gb_w% h50 x%x_left% y+%pad2% +HWNDhwnd, Open Twitch Rewards Page
                ;~ this.add_control_method(hwnd, this, "open_url", this.url.twitch_rewards)
            
            ; Notify options
            
            
            ; Donations maybe?
            ; Gui, Add, Checkbox, x%x_left% y+%pad% +HWNDhwnd, option1
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
            GuiControl, , % this.gHwnd.check_per_sec
                , % "Checking every " Round(60 / this.interval) " seconds" 
            Return 
        }
        
        start_update_check_timer()
        {
            bf  := ObjBindMethod(this, "update_check")
            SetTimer, % bf, % Abs(this.update_freq) * -1000
            Return
        }
        
        update_interval(hwnd, gui_event, event_info, err_level:="")
        {
            GuiControlGet, interval,, % hwnd
            this.interval := interval
            this.next_beat()
            this.update_interval_per_sec()
            Return
        }
        
        notify_action(name, hwnd, GuiEvent, EventInfo, ErrLevel:="")
        {
            GuiControlGet, state, , % hwnd                  ; Get check state
            this.notify_list[name] := state                 ; Update state into notify list
            this.save_settings("notify_list", name, state)  ; Save to settins file
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
                    MsgBox Change! Need to update!
                    GuiControl,, % this.gHwnd[user.username].status_pic
                        , % this.path[(user.status ? "img_online" : "img_offline")]
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
                If !InStr(con, "button") && !InStr(con, "trackbar321")
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
            WinGetPos, x, y,,, % "ahk_id " this.gHwnd.main
            this.last_x := x
            , this.last_y := y
            Return
        }
        
        save_last_xy()
        {
            this.update_last_xy()
            , this.save_settings("main_gui", "last_x", this.last_x)
            , this.save_settings("main_gui", "last_y", this.last_y)
            Return
        }
        
        Show()
        {
            this.load_last_xy()
            (this.last_x*0 = 0 ? "" : this.last_x := 0)
            (this.last_y*0 = 0 ? "" : this.last_y := 0)
            Gui, Main:Show, % "AutoSize x" this.last_x " y" this.last_y, % this.gui_name ;Center, % this.title
            this.visible := True
        }
        
        Hide()
        {
            this.save_last_xy()
            Gui, Main:Hide
            this.visible := False
        }
        
        Toggle()
        {
            this.visible
                ? this.Hide() 
                : this.Show()
        }
        
        quit()
        {
            MsgBox, 0x4, Exiting, Close program?
            IfMsgBox, Yes
                ExitApp
            Return
        }
    }
    
    Class splash extends rust_checker
    {
        Static  gHwnd        := {}
                ,font_opt   := "s20 Bold "
        start(msg)
        {
            pad         := 10
            , padO      := 12
            , pad2      := pad*2
            , padO2     := padO*2
            , gui_w     := 220
            , gui_h     := 120
            , txt_w     := gui_w - pad2
            , txt_h     := gui_h - pad2
            , scrn_t    := scrn_r := scrn_b := scrn_l := 0
            , this.get_monitor_workarea(scrn_t, scrn_r, scrn_b, scrn_l)
            , this.img_getter(this.url.git_img_symbol, this.path.img, "Rust_Symbol.png")
            
            Gui, splash:New, -Caption +HWNDhwnd +Border +ToolWindow +AlwaysOnTop
                this.gHwnd.gui := hwnd
            Gui, splash:Default
            Gui, Margin, 0, 0
            Gui, Color, 0x000001
            
            Gui, Add, Picture, w%gui_w% h%gui_h% x0 y0, % rust_checker.path.rust_icon
            Gui, Font, % "s20 cBlack Bold", Consolas
            Gui, Add, Text, w%txt_w% h%txt_h% x%pad% y%pad% +HWNDhwnd +Center +BackgroundTrans, % msg
                this.gHwnd.txt_shadow := hwnd
            Gui, Font, % "s20 cWhite Norm", Consolas
            Gui, Add, Text, w%txt_w% h%txt_h% x%padO% y%padO% +HWNDhwnd +Center +BackgroundTrans, % msg
                this.gHwnd.txt := hwnd
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
            GuiControl,, % this.gHwnd.txt_shadow, % txt
            Gui, Font, % "s20 cWhite Norm", Consolas
            GuiControl,, % this.gHwnd.txt, % txt
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
        GuiControl, Text, % this.main_gui.gHwnd.updater_btn, % (update_found ? "Update Available!" : "Up To Date :D")
        ; Enable/disable
        GuiControl, % (update_found ? "Enable" : "Disable"), % this.main_gui.gHwnd.updater_btn
        /*
            GuiControl, +cDA4F49, Red
            GuiControl,, Red, Red Text
        return
        
        Black:
            GuiControl, +c000000, Red
            GuiControl,, Red, Black Text
        */
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
    
    open_url(url)
    {
        Run, % url
        Return
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
