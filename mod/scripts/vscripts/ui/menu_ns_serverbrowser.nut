global function AddNorthstarServerBrowserMenu
global function ThreadedAuthAndConnectToServer

// Stop peeking
// Code is a mess rn, will clean up

const int BUTTONS_PER_PAGE = 15
const int DOUBLE_CLICK_TIME_MS = 100

struct {
	bool hideFull = false
	bool hideEmpty = false
	bool hideProtected = false
	bool useSearch = false
	string searchTerm
} filterArguments

struct {
	// true = alphabeticaly false = reverse
	bool serverName = true
	bool serverPlayers = true
	bool serverMap = true
	bool serverGamemode = true
	bool serverLatency = true
} filterDirection

struct serverStruct {
	int serverIndex
	bool serverProtected
	string serverName
	int serverPlayers
	int serverPlayersMax
	string serverMap
	string serverGamemode
	int serverLatency
}

array<serverStruct> serversArrayFiltered

struct {
	var menu
	int lastSelectedServer = 0
	int focusedServerIndex = 0
	int scrollOffset = 0
	bool serverListRequestFailed = false
	float serverSelectedTime = 0
	float serverSelectedTimeLast = 0
} file

// string.find() works like 10% of the time
// https://www.csestack.org/implement-strstr-function-in-c/
bool function strstr(string str, string strSub)
{
    int i = 0
		int j = 0
    int nTemp = i
    int nStrLen = str.len()
    int nStrSubLen = strSub.len()
    for(i = 0; i < nStrLen - nStrSubLen; i++)
    {
        nTemp = i
        for(j = 0; j < nStrSubLen; j++)
        {

            if ( str [ nTemp ] == strSub[ j ] )
            {
                if ( j == nStrSubLen - 1 ) return true
                nTemp++
            }
            else
                break
        }
    }
    return false
}


void function AddNorthstarServerBrowserMenu()
{
	AddMenu( "ServerBrowserMenu", $"resource/ui/menus/server_browser.menu", InitServerBrowserMenu, "#MENU_SERVER_BROWSER" )
}

void function InitServerBrowserMenu()
{
	file.menu = GetMenu( "ServerBrowserMenu" )

	//AddMenuEventHandler( file.menu, eUIEvent.MENU_OPEN, OnOpenServerBrowserMenu )
	AddMenuEventHandler( file.menu, eUIEvent.MENU_CLOSE, OnCloseServerBrowserMenu )



	AddMenuEventHandler( file.menu, eUIEvent.MENU_OPEN, OnServerBrowserMenuOpened )
	AddMenuFooterOption( file.menu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	AddMenuFooterOption( file.menu, BUTTON_Y, "#Y_REFRESH_SERVERS", "#REFRESH_SERVERS", RefreshServers )


	foreach ( var button in GetElementsByClassname( GetMenu( "ServerBrowserMenu" ), "ServerButton" ) )
	{
		AddButtonEventHandler( button, UIE_CLICK, OnServerFocused )
	}

	AddButtonEventHandler( Hud_GetChild( file.menu, "BtnServerJoin"), UIE_CLICK, OnServerSelected )

	AddButtonEventHandler( Hud_GetChild( file.menu, "BtnServerListUpArrow"), UIE_CLICK, OnUpArrowSelected )
	AddButtonEventHandler( Hud_GetChild( file.menu, "BtnServerListDownArrow"), UIE_CLICK, OnDownArrowSelected )



	AddButtonEventHandler( Hud_GetChild( file.menu, "BtnFiltersClear"), UIE_CLICK, OnBtnFiltersClear_Activate )

	AddButtonEventHandler( Hud_GetChild( file.menu, "BtnServerNameTab"), UIE_CLICK, SortServerListByName )
	AddButtonEventHandler( Hud_GetChild( file.menu, "BtnServerPlayersTab"), UIE_CLICK, SortServerListByPlayers )
	AddButtonEventHandler( Hud_GetChild( file.menu, "BtnServerMapTab"), UIE_CLICK, SortServerListByMap )
	AddButtonEventHandler( Hud_GetChild( file.menu, "BtnServerGamemodeTab"), UIE_CLICK, SortServerListByGamemode )
	AddButtonEventHandler( Hud_GetChild( file.menu, "BtnServerGamemodeTab"), UIE_CLICK, SortServerListByLatency )


	AddButtonEventHandler( Hud_GetChild( file.menu, "SwtBtnSelectMap"), UIE_CLICK, FilterAndUpdateList )
	AddButtonEventHandler( Hud_GetChild( file.menu, "SwtBtnSelectGamemode"), UIE_CLICK, FilterAndUpdateList )
	AddButtonEventHandler( Hud_GetChild( file.menu, "SwtBtnHideFull"), UIE_CLICK, FilterAndUpdateList )
	AddButtonEventHandler( Hud_GetChild( file.menu, "SwtBtnHideEmpty"), UIE_CLICK, FilterAndUpdateList )
	AddButtonEventHandler( Hud_GetChild( file.menu, "SwtBtnHideProtected"), UIE_CLICK, FilterAndUpdateList )

	AddButtonEventHandler( Hud_GetChild( file.menu, "BtnServerDescription"), UIE_CLICK, ShowServerDescription )
	AddButtonEventHandler( Hud_GetChild( file.menu, "BtnServerMods"), UIE_CLICK, ShowServerMods )

	// Hidden cause no need, if server descriptions become too long use this
	Hud_SetEnabled( Hud_GetChild( file.menu, "BtnServerDescription"), false)
	Hud_SetEnabled( Hud_GetChild( file.menu, "BtnServerMods"), false)
	Hud_SetText( Hud_GetChild( file.menu, "BtnServerDescription"), "")
	Hud_SetText( Hud_GetChild( file.menu, "BtnServerMods"), "")

	// Unfinished features
	Hud_SetLocked( Hud_GetChild( file.menu, "BtnServerListSlider" ), true )
	Hud_SetLocked( Hud_GetChild( file.menu, "BtnServerLatencyTab" ), true )
	Hud_SetLocked( Hud_GetChild( file.menu, "SwtBtnSelectMap" ), true )
	Hud_SetLocked( Hud_GetChild( file.menu, "SwtBtnSelectGamemode" ), true )

	// Rui is a pain
	RuiSetString( Hud_GetRui( Hud_GetChild( file.menu, "SwtBtnHideFull")), "buttonText", "")
	RuiSetString( Hud_GetRui( Hud_GetChild( file.menu, "SwtBtnHideEmpty")), "buttonText", "")
	RuiSetString( Hud_GetRui( Hud_GetChild( file.menu, "SwtBtnHideProtected")), "buttonText", "")
	RuiSetString( Hud_GetRui( Hud_GetChild( file.menu, "SwtBtnSelectMap")), "buttonText", "")
	RuiSetString( Hud_GetRui( Hud_GetChild( file.menu, "SwtBtnSelectGamemode")), "buttonText", "")
}


void function OnCloseServerBrowserMenu()
{
	DeregisterButtonPressedCallback(MOUSE_WHEEL_UP , OnScrollUp)
	DeregisterButtonPressedCallback(MOUSE_WHEEL_DOWN , OnScrollDown)
	DeregisterButtonPressedCallback(KEY_ENTER , FilterAndUpdateList)
}


void function OnDownArrowSelected( var button )
{
	if (serversArrayFiltered.len() <= 15) return
	file.scrollOffset += 1
	if (file.scrollOffset + BUTTONS_PER_PAGE > serversArrayFiltered.len()) file.scrollOffset = serversArrayFiltered.len() - BUTTONS_PER_PAGE
	UpdateShownPage()
	UpdateListSliderPosition( serversArrayFiltered.len() )
}


void function OnUpArrowSelected( var button )
{
	file.scrollOffset -= 1
	if (file.scrollOffset < 0) file.scrollOffset = 0
	UpdateShownPage()
	UpdateListSliderPosition( serversArrayFiltered.len() )
}


void function OnScrollDown( var button )
{
	if (serversArrayFiltered.len() <= 15) return
	file.scrollOffset += 5
	if (file.scrollOffset + BUTTONS_PER_PAGE > serversArrayFiltered.len()) file.scrollOffset = serversArrayFiltered.len() - BUTTONS_PER_PAGE
	UpdateShownPage()
	UpdateListSliderPosition( serversArrayFiltered.len() )
}

void function OnScrollUp( var button )
{
	file.scrollOffset -= 5
	if (file.scrollOffset < 0) file.scrollOffset = 0
	UpdateShownPage()
	UpdateListSliderPosition( serversArrayFiltered.len() )
}


void function UpdateListSliderHeight( float servers )
{
	var sliderButton = Hud_GetChild( file.menu , "BtnServerListSlider" )
	var sliderPanel = Hud_GetChild( file.menu , "BtnServerListSliderPanel" )

	float maxHeight = 562.0 * (GetScreenSize()[1] / 1080.0)

	float height = maxHeight * (15.0 / servers )

	if ( height > maxHeight ) height = maxHeight

	Hud_SetHeight( sliderButton , height )
	Hud_SetHeight( sliderPanel , height )
}


void function UpdateListSliderPosition( int servers)
{
	var sliderButton = Hud_GetChild( file.menu , "BtnServerListSlider" )
	var sliderPanel = Hud_GetChild( file.menu , "BtnServerListSliderPanel" )

	float minYPos = -40.0 * (GetScreenSize()[1] / 1080.0)
	float useableSpace = (562.0 * (GetScreenSize()[1] / 1080.0) - Hud_GetHeight( sliderButton ))

	float jump = minYPos - (useableSpace / ( float( servers ) - 15.0 ) * file.scrollOffset)

	//jump = jump * (GetScreenSize()[1] / 1080.0)

	if ( jump > minYPos ) jump = minYPos

	Hud_SetPos( sliderButton , 4, jump )
	Hud_SetPos( sliderPanel , 4, jump )
}


void function ShowServerDescription( var button )
{
	Hud_SetVisible( Hud_GetChild( file.menu, "LabelDescription"), true)
	Hud_SetVisible( Hud_GetChild( file.menu, "LabelMods"), false)
}

void function ShowServerMods( var button )
{
	Hud_SetVisible( Hud_GetChild( file.menu, "LabelDescription"), false)
	Hud_SetVisible( Hud_GetChild( file.menu, "LabelMods"), true)
}


void function OnBtnFiltersClear_Activate( var button )
{
	Hud_SetText( Hud_GetChild( file.menu, "BtnServerSearch" ), "" )

	SetConVarBool( "filter_hide_empty", false )
	SetConVarBool( "filter_hide_full", false )
	SetConVarBool( "filter_hide_protected", false )

	FilterAndUpdateList(0)
}


void function OnServerBrowserMenuOpened()
{
	Hud_SetText( Hud_GetChild( GetMenu( "ServerBrowserMenu" ), "Title" ), "#MENU_TITLE_SERVER_BROWSER" )
	UI_SetPresentationType( ePresentationType.KNOWLEDGEBASE_MAIN )

	file.scrollOffset = 0
	// dont rerequest if we came from the connect menu
	if ( !NSIsRequestingServerList() && uiGlobal.lastMenuNavDirection != MENU_NAV_BACK )
	{
		NSClearRecievedServerList()
		NSRequestServerList()
	}

	thread WaitForServerListRequest()

	// Scroll wheel scrolling is fucky af
	RegisterButtonPressedCallback(MOUSE_WHEEL_UP , OnScrollUp)
	RegisterButtonPressedCallback(MOUSE_WHEEL_DOWN , OnScrollDown)
	RegisterButtonPressedCallback(KEY_ENTER , FilterAndUpdateList)
}


void function SortServerListByName( var button )
{

	int n = serversArrayFiltered.len() - 1

	serverStruct tempServer

	for ( int i = 0; i < n; i++)
	{
		for ( int j = 0; j < n - 1; j++)
		{
			if ( serversArrayFiltered[ j ].serverName < serversArrayFiltered[ j + 1 ].serverName && filterDirection.serverName || serversArrayFiltered[ j ].serverName > serversArrayFiltered[ j + 1 ].serverName && !filterDirection.serverName)
			{
				tempServer = serversArrayFiltered[ j ]
				serversArrayFiltered[ j ] = serversArrayFiltered[ j + 1 ]
				serversArrayFiltered[ j + 1 ] = tempServer
			}
		}
	}

	filterDirection.serverName = !filterDirection.serverName

	UpdateShownPage()
}

void function SortServerListByPlayers( var button )
{

	int n = serversArrayFiltered.len() - 1

	serverStruct tempServer

	for ( int i = 0; i < n; i++)
	{
		for ( int j = 0; j < n - 1; j++)
		{
			if ( serversArrayFiltered[ j ].serverPlayers < serversArrayFiltered[ j + 1 ].serverPlayers && filterDirection.serverPlayers || serversArrayFiltered[ j ].serverPlayers > serversArrayFiltered[ j + 1 ].serverPlayers && !filterDirection.serverPlayers)
			{
				tempServer = serversArrayFiltered[ j ]
				serversArrayFiltered[ j ] = serversArrayFiltered[ j + 1 ]
				serversArrayFiltered[ j + 1 ] = tempServer
			}
		}
	}

	filterDirection.serverPlayers = !filterDirection.serverPlayers

	UpdateShownPage()
}

void function SortServerListByMap( var button )
{

	int n = serversArrayFiltered.len() - 1

	serverStruct tempServer

	for ( int i = 0; i < n; i++)
	{
		for ( int j = 0; j < n - 1; j++)
		{
			if ( serversArrayFiltered[ j ].serverMap < serversArrayFiltered[ j + 1 ].serverMap && filterDirection.serverMap || serversArrayFiltered[ j ].serverMap > serversArrayFiltered[ j + 1 ].serverMap && !filterDirection.serverMap)
			{
				tempServer = serversArrayFiltered[ j ]
				serversArrayFiltered[ j ] = serversArrayFiltered[ j + 1 ]
				serversArrayFiltered[ j + 1 ] = tempServer
			}
		}
	}

	filterDirection.serverMap = !filterDirection.serverMap

	UpdateShownPage()
}

void function SortServerListByGamemode( var button )
{

	int n = serversArrayFiltered.len() - 1

	serverStruct tempServer

	for ( int i = 0; i < n; i++)
	{
		for ( int j = 0; j < n - 1; j++)
		{
			if ( serversArrayFiltered[ j ].serverGamemode < serversArrayFiltered[ j + 1 ].serverGamemode && filterDirection.serverGamemode || serversArrayFiltered[ j ].serverGamemode > serversArrayFiltered[ j + 1 ].serverGamemode && !filterDirection.serverGamemode)
			{
				tempServer = serversArrayFiltered[ j ]
				serversArrayFiltered[ j ] = serversArrayFiltered[ j + 1 ]
				serversArrayFiltered[ j + 1 ] = tempServer
			}
		}
	}

	filterDirection.serverGamemode = !filterDirection.serverGamemode

	UpdateShownPage()
}

void function SortServerListByLatency( var button )
{

	int n = serversArrayFiltered.len() - 1

	serverStruct tempServer

	for ( int i = 0; i < n; i++)
	{
		for ( int j = 0; j < n - 1; j++)
		{
			if ( serversArrayFiltered[ j ].serverLatency < serversArrayFiltered[ j + 1 ].serverLatency && filterDirection.serverLatency || serversArrayFiltered[ j ].serverLatency > serversArrayFiltered[ j + 1 ].serverLatency && !filterDirection.serverLatency)
			{
				tempServer = serversArrayFiltered[ j ]
				serversArrayFiltered[ j ] = serversArrayFiltered[ j + 1 ]
				serversArrayFiltered[ j + 1 ] = tempServer
			}
		}
	}

	filterDirection.serverLatency = !filterDirection.serverLatency

	UpdateShownPage()
}

void function FilterAndUpdateList( var n)
{
	filterArguments.searchTerm = Hud_GetUTF8Text( Hud_GetChild( file.menu, "BtnServerSearch" ) )
	if ( filterArguments.searchTerm == "" ) filterArguments.useSearch = false else filterArguments.useSearch = true
	filterArguments.hideEmpty = GetConVarBool( "filter_hide_empty" )
	filterArguments.hideFull = GetConVarBool( "filter_hide_full" )
	filterArguments.hideProtected = GetConVarBool( "filter_hide_protected" )
	file.scrollOffset = 0
	FilterServerList()
	UpdateShownPage()
}


void function RefreshServers( var button )
{
	if ( NSIsRequestingServerList() )
		return

	file.serverListRequestFailed = false
	file.scrollOffset = 0
	NSClearRecievedServerList()
	NSRequestServerList()

	thread WaitForServerListRequest()
}


void function WaitForServerListRequest()
{
	var menu = GetMenu( "ServerBrowserMenu" )
	array<var> serverButtons = GetElementsByClassname( menu, "ServerButton" )
	foreach ( var button in serverButtons )
	{
		Hud_SetVisible( button, false )
	}


	Hud_SetVisible( Hud_GetChild( menu, "LabelDescription" ), false )
	Hud_SetVisible( Hud_GetChild( menu, "LabelMods" ), false )
	Hud_SetVisible( Hud_GetChild( menu, "NextMapImage" ), false )
	Hud_SetVisible( Hud_GetChild( menu, "NextMapName" ), false )
	Hud_SetVisible( Hud_GetChild( menu, "NextModeIcon" ), false )
	Hud_SetVisible( Hud_GetChild( menu, "NextGameModeName" ), false )
	Hud_SetVisible( Hud_GetChild( menu, "ServerName" ), false )
	Hud_SetVisible( Hud_GetChild( menu, "BtnServerDescription" ), false )
	Hud_SetVisible( Hud_GetChild( menu, "BtnServerMods" ), false )
	Hud_SetVisible( Hud_GetChild( menu, "BtnServerJoin" ), false )


	Hud_SetVisible( serverButtons[ 0 ], true )

	Hud_SetText( serverButtons[ 0 ], "#NS_SERVERBROWSER_WAITINGFORSERVERS" )

	// wait for request to complete
	while ( NSIsRequestingServerList() )
		WaitFrame()

	file.serverListRequestFailed = !NSMasterServerConnectionSuccessful()
	if ( file.serverListRequestFailed )
	{
		Hud_SetText( serverButtons[ 0 ], "#NS_SERVERBROWSER_CONNECTIONFAILED" )
	}
	else
	{
		FilterAndUpdateList(0)
	}
}



void function FilterServerList()
{
	serversArrayFiltered.clear()
	for ( int i = 0; i < NSGetServerCount(); i++ )
	{
		serverStruct tempServer
		tempServer.serverIndex = i
		tempServer.serverProtected = NSServerRequiresPassword( i )
		tempServer.serverName = NSGetServerName( i )
		tempServer.serverPlayers = NSGetServerPlayerCount( i )
		tempServer.serverPlayersMax = NSGetServerMaxPlayerCount( i )
		tempServer.serverMap = NSGetServerMap( i )
		tempServer.serverGamemode = GetGameModeDisplayName( NSGetServerPlaylist ( i ) )


		// Branchless programming ;)
		if (!(filterArguments.hideEmpty && tempServer.serverPlayers == 0))
		{
			if (!(filterArguments.hideFull && tempServer.serverPlayers == tempServer.serverPlayersMax))
			{
				if (!(filterArguments.hideProtected && tempServer.serverProtected))
				{
					if ( filterArguments.useSearch )
					{
						string sName = tempServer.serverName.tolower()
						string sTerm = filterArguments.searchTerm.tolower()

						if ( strstr(sName, sTerm) )
						{
							serversArrayFiltered.append( tempServer )
							printt( sTerm, " is in ", sName)
						}
						else
						{
							printt( sTerm, "isn't in ", sName)
						}
					}
					else
					{
						serversArrayFiltered.append( tempServer )
					}
				}
			}
		}
	}
}


void function UpdateShownPage()
{
	var menu = GetMenu( "ServerBrowserMenu" )

	// Get and Hide serverButtons
	array<var> serverButtons = GetElementsByClassname( menu, "ServerButton" )
	array<var> playerCountLabels = GetElementsByClassname( menu, "PlayerCount" )
	array<var> serversProtected = GetElementsByClassname( menu, "ServerLock" )
	array<var> serversMap = GetElementsByClassname( menu, "ServerMap" )
	array<var> serversGamemode = GetElementsByClassname( menu, "ServerGamemode" )
	array<var> serversLatency = GetElementsByClassname( menu, "ServerLatency" )

	for ( int i = 0; i < 15; i++)
	{
		Hud_SetVisible( serversProtected[ i ], false )
		Hud_SetVisible( serverButtons[ i ], false )
		Hud_SetText( serverButtons[ i ], "" )
		Hud_SetText( playerCountLabels[ i ], "" )
		Hud_SetText( serversMap[ i ], "" )
		Hud_SetText( serversGamemode[ i ], "" )
		Hud_SetText( serversLatency[ i ], "" )
	}

	int j = serversArrayFiltered.len() > 15 ? 15 : serversArrayFiltered.len()

	for ( int i = 0; i < j; i++ )
	{

		int buttonIndex = file.scrollOffset + i
		int serverIndex = serversArrayFiltered[ buttonIndex ].serverIndex

		Hud_SetEnabled( serverButtons[ i ], true )
		Hud_SetVisible( serverButtons[ i ], true )

		Hud_SetVisible( serversProtected[ i ], serversArrayFiltered[ buttonIndex ].serverProtected )
		Hud_SetText( serverButtons[ i ], serversArrayFiltered[ buttonIndex ].serverName )
		Hud_SetText( playerCountLabels[ i ], format( "%i/%i", serversArrayFiltered[ buttonIndex ].serverPlayers, serversArrayFiltered[ buttonIndex ].serverPlayersMax ) )
		Hud_SetText( serversMap[ i ], GetMapDisplayName( serversArrayFiltered[ buttonIndex ].serverMap ) )
		Hud_SetText( serversGamemode[ i ], serversArrayFiltered[ buttonIndex ].serverGamemode )
	}


	if ( NSGetServerCount() == 0 )
	{
		Hud_SetEnabled( serverButtons[ 0 ], true )
		Hud_SetVisible( serverButtons[ 0 ], true )
		Hud_SetText( serverButtons[ 0 ], "#NS_SERVERBROWSER_NOSERVERS" )
	}

	UpdateListSliderHeight( float( serversArrayFiltered.len() ) )
	UpdateListSliderPosition( serversArrayFiltered.len() )
}


void function OnServerFocused( var button )
{
	if ( NSIsRequestingServerList() || NSGetServerCount() == 0 || file.serverListRequestFailed )
		return

	var menu = GetMenu( "ServerBrowserMenu" )

	file.focusedServerIndex = serversArrayFiltered[ file.scrollOffset + int ( Hud_GetScriptID( button ) ) ].serverIndex
	int serverIndex = file.scrollOffset + int ( Hud_GetScriptID( button ) )

	bool sameServer = false
	if (file.lastSelectedServer == serverIndex) sameServer = true

	printt(sameServer)

	file.lastSelectedServer = serverIndex

	file.serverSelectedTimeLast = file.serverSelectedTime
	file.serverSelectedTime = Time()

	if ((file.serverSelectedTime - file.serverSelectedTimeLast < DOUBLE_CLICK_TIME_MS) && sameServer)
		OnServerSelected(0)


	Hud_SetVisible( Hud_GetChild( menu, "BtnServerDescription" ), true )
	Hud_SetVisible( Hud_GetChild( menu, "BtnServerMods" ), true )
	Hud_SetVisible( Hud_GetChild( menu, "BtnServerJoin" ), true )
	// text panels
	Hud_SetVisible( Hud_GetChild( menu, "LabelDescription" ), true )
	Hud_SetVisible( Hud_GetChild( menu, "LabelMods" ), false )
	//RuiSetGameTime( textRui, "startTime", -99999.99 ) // make sure it skips the whole animation for showing this
	Hud_SetText( Hud_GetChild( menu, "LabelDescription" ), NSGetServerDescription( serversArrayFiltered[ serverIndex ].serverIndex ) + "\n\nRequired Mods:\n" + FillInServerModsLabel( serversArrayFiltered[ serverIndex ].serverIndex ))
	//Hud_SetText( Hud_GetChild( menu, "LabelMods" ), FillInServerModsLabel( serversArrayFiltered[ serverIndex ].serverIndex ) )

	// map name/image/server name
	string map = serversArrayFiltered[ serverIndex ].serverMap
	Hud_SetVisible( Hud_GetChild( menu, "NextMapImage" ), true )
	RuiSetImage( Hud_GetRui( Hud_GetChild( menu, "NextMapImage" ) ), "basicImage", GetMapImageForMapName( map ) )
	Hud_SetVisible( Hud_GetChild( menu, "NextMapName" ), true )
	Hud_SetText( Hud_GetChild( menu, "NextMapName" ), GetMapDisplayName( map ) )
	Hud_SetVisible( Hud_GetChild( menu, "ServerName" ), true )
	Hud_SetText( Hud_GetChild( menu, "ServerName" ), NSGetServerName( serversArrayFiltered[ serverIndex ].serverIndex ) )

	// mode name/image
	string mode = serversArrayFiltered[ serverIndex ].serverGamemode
	Hud_SetVisible( Hud_GetChild( menu, "NextModeIcon" ), true )
	RuiSetImage( Hud_GetRui( Hud_GetChild( menu, "NextModeIcon" ) ), "basicImage", GetPlaylistThumbnailImage( mode ) )
	Hud_SetVisible( Hud_GetChild( menu, "NextGameModeName" ), true )

	if ( mode.len() != 0 )
		Hud_SetText( Hud_GetChild( menu, "NextGameModeName" ), mode )
	else
		Hud_SetText( Hud_GetChild( menu, "NextGameModeName" ), "#NS_SERVERBROWSER_UNKNOWNMODE" )
}


string function FillInServerModsLabel( int server )
{
	string ret

	for ( int i = 0; i < NSGetServerRequiredModsCount( server ); i++ )
	{
		ret += "  "
		ret += NSGetServerRequiredModName( server, i ) + " v" + NSGetServerRequiredModVersion( server, i ) + "\n"
	}
	return ret
}


void function OnServerSelected( var button )
{
	if ( NSIsRequestingServerList() || NSGetServerCount() == 0 || file.serverListRequestFailed )
		return

	int serverIndex = file.focusedServerIndex

	file.lastSelectedServer = serverIndex

	// check mods
	for ( int i = 0; i < NSGetServerRequiredModsCount( serverIndex ); i++ )
	{
		if ( !NSGetModNames().contains( NSGetServerRequiredModName( serverIndex, i ) ) )
		{
			DialogData dialogData
			dialogData.header = "#ERROR"
			dialogData.message = "Missing mod \"" + NSGetServerRequiredModName( serverIndex, i ) + "\" v" + NSGetServerRequiredModVersion( serverIndex, i )
			dialogData.image = $"ui/menu/common/dialog_error"

			#if PC_PROG
				AddDialogButton( dialogData, "#DISMISS" )

				AddDialogFooter( dialogData, "#A_BUTTON_SELECT" )
			#endif // PC_PROG
			AddDialogFooter( dialogData, "#B_BUTTON_DISMISS_RUI" )

			OpenDialog( dialogData )

			return
		}
		else
		{
			// this uses semver https://semver.org
			array<string> serverModVersion = split( NSGetServerRequiredModVersion( serverIndex, i ), "." )
			array<string> clientModVersion = split( NSGetModVersionByModName( NSGetServerRequiredModName( serverIndex, i ) ), "." )

			bool semverFail = false
			// if server has invalid semver don't bother checking
			if ( serverModVersion.len() == 3 )
			{
				// bad client semver
				if ( clientModVersion.len() != serverModVersion.len() )
					semverFail = true
				// major version, don't think we should need to check other versions
				else if ( clientModVersion[ 0 ] != serverModVersion[ 0 ] )
					semverFail = true
			}

			if ( semverFail )
			{
				DialogData dialogData
				dialogData.header = "#ERROR"
				dialogData.message = "Server has mod \"" + NSGetServerRequiredModName( serverIndex, i ) + "\" v" + NSGetServerRequiredModVersion( serverIndex, i ) + " while we have v" + NSGetModVersionByModName( NSGetServerRequiredModName( serverIndex, i ) )
				dialogData.image = $"ui/menu/common/dialog_error"

				#if PC_PROG
					AddDialogButton( dialogData, "#DISMISS" )

					AddDialogFooter( dialogData, "#A_BUTTON_SELECT" )
				#endif // PC_PROG
				AddDialogFooter( dialogData, "#B_BUTTON_DISMISS_RUI" )

				OpenDialog( dialogData )

				return
			}
		}
	}

	if ( NSServerRequiresPassword( serverIndex ) )
		AdvanceMenu( GetMenu( "ConnectWithPasswordMenu" ) )
	else
		thread ThreadedAuthAndConnectToServer()
}


void function ThreadedAuthAndConnectToServer( string password = "" )
{
	if ( NSIsAuthenticatingWithServer() )
		return

	print( "trying to authenticate with server " + NSGetServerName( file.lastSelectedServer ) + " with password " + password )
	NSTryAuthWithServer( file.lastSelectedServer, password )

	while ( NSIsAuthenticatingWithServer() )
		WaitFrame()

	if ( NSWasAuthSuccessful() )
	{
		bool modsChanged

		array<string> requiredMods
		for ( int i = 0; i < NSGetServerRequiredModsCount( file.lastSelectedServer ); i++ )
			requiredMods.append( NSGetServerRequiredModName( file.lastSelectedServer, i ) )

		// unload mods we don't need, load necessary ones and reload mods before connecting
		foreach ( string mod in NSGetModNames() )
		{
			if ( NSIsModRequiredOnClient( mod ) )
			{
				modsChanged = modsChanged || NSIsModEnabled( mod ) != requiredMods.contains( mod )
				NSSetModEnabled( mod, requiredMods.contains( mod ) )
			}
		}

		// only actually reload if we need to since the uiscript reset on reload lags hard
		if ( modsChanged )
			ReloadMods()

		NSConnectToAuthedServer()
	}
	else
	{
		DialogData dialogData
		dialogData.header = "#ERROR"
		dialogData.message = "Authentication Failed"
		dialogData.image = $"ui/menu/common/dialog_error"

		#if PC_PROG
			AddDialogButton( dialogData, "#DISMISS" )

			AddDialogFooter( dialogData, "#A_BUTTON_SELECT" )
		#endif // PC_PROG
		AddDialogFooter( dialogData, "#B_BUTTON_DISMISS_RUI" )

		OpenDialog( dialogData )
	}
}
