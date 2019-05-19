//# sourceURL=J_Switchboard_UI7.js
/**
 * J_Switchboard1_UI7.js
 * Configuration interface for Switchboard
 *
 * Copyright 2019 Patrick H. Rigney, All Rights Reserved.
 * This file is part of Switchboard. For license information, see LICENSE at https://github.com/toggledbits/Switchboard
 */
/* globals api,jQuery,$,MultiBox */
/* jshint multistr: true */

//"use strict"; // fails on UI7, works fine with ALTUI

var Switchboard1_UI7 = (function(api, $) {

	var pluginVersion = "1.3develop-19139";

	var _UIVERSION = 371; /* must agree with L_Switchboard1.lua */

	/* unique identifier for this plugin... */
	var uuid = 'fabe8224-2341-11e9-8762-74d4351650de'; /* 2019-01-28 Switchboard */

	var myModule = {};

	var serviceId = "urn:toggledbits-com:serviceId:Switchboard1";
	// var deviceType = "urn:schemas-toggledbits-com:device:Switchboard:1";

	var inStatusPanel = false;
	var isOpenLuup = false;
	var isALTUI = ( "undefined" !== typeof(MultiBox) );

	/* Closing the control panel. */
	function onBeforeCpanelClose(args) {
		inStatusPanel = false;
	}

	/* Return footer */
	function footer() {
		var html = '';
		html += '<div class="clearfix">';
		html += '<div id="tbbegging"><em>Find Switchboard useful?</em> Please consider a small one-time donation to support this and my other plugins on <a href="https://www.toggledbits.com/donate" target="_blank">my web site</a>. I am grateful for any support you choose to give!</div>';
		html += '<div id="tbcopyright">Switchboard ver ' + pluginVersion + ' &copy; 2019 <a href="https://www.toggledbits.com/" target="_blank">Patrick H. Rigney</a>,' +
			' All Rights Reserved.' +
			' <a href="https://community.getvera.com/t/new-plugin-switchboard-virtual-switches-re-imagined/200515/1" target="_blank">Support Forum Thread</a> &#149; <a href="https://github.com/toggledbits/Switchboard-Vera/" target="_blank">Documentation and license information</a>.';
		try {
			html += '<div id="browserident">' + navigator.userAgent + '</div>';
		} catch( e ) {}

		return html;
	}

	function initModule() {
		var myid = api.getCpanelDeviceId();

		/* Check agreement of plugin core and UI */
		var s = api.getDeviceState( myid, "urn:toggledbits-com:serviceId:Switchboard1", "_UIV" ) || "0";
		console.log("initModule() for device " + myid + " requires UI version " + _UIVERSION + ", seeing " + s);
		if ( String(_UIVERSION) != s ) {
			api.setCpanelContent( '<div style="border: 4px solid red; padding: 8px;">' +
				" ERROR! The Switchboard plugin core version and UI version do not agree." +
				" This may cause errors or corrupt your Switchboard configuration." +
				" Please hard-reload your browser and try again " +
				' (<a href="https://duckduckgo.com/?q=hard+reload+browser" target="_blank">how?</a>).' +
				" If you have installed hotfix patches, you may not have successfully installed all required files." +
				" Expected " + String(_UIVERSION) + " got " + String(s) +
				".</div>" );
			return false;
		}

		var dl = api.getListOfDevices();
		for ( var ix=0; ix<dl.length; ++ix ) {
			if ( dl[ix].device_type == "openLuup" && dl[ix].id_parent == 0 ) {
				isOpenLuup = true;
				break;
			}
		}

		api.registerEventHandler('on_ui_cpanel_before_close', Switchboard1_UI7, 'onBeforeCpanelClose');
		inStatusPanel = false;

		/* Load material design icons */
		jQuery("head").append('<link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">');
		jQuery("head").append('\
<style> \
	div#tbcopyright { display: block; margin: 12px 0px; } \
	div#tbbegging { display: block; color: #ff6600; margin-top: 12px; } \
</style>');

		return true;
	}

	function getDevices(pdev) {
		var dl = api.getListOfDevices();
		var dd = [];
		for ( var ix=0; ix<dl.length; ++ix ) {
			var dobj = dl[ix];
			if ( dobj.id_parent == pdev ) {
				dd.push( dobj );
			}
		}
		dd.sort( function( a, b ) {
			var an = a.name.toLowerCase();
			var bn = b.name.toLowerCase();
			if ( an == bn ) return 0;
			return an < bn ? -1 : 1;
		});
		return dd;
	}

	function handleStateClick( ev ) {
		var el = jQuery( ev.currentTarget );
		var row = el.closest( 'div.row' );
		var dev = parseInt( row.attr( 'id' ).replace( /^d/i, "" ) );
		api.performActionOnDevice( dev, "urn:micasaverde-com:serviceId:HaDevice1", "ToggleState", { actionArguments: {} });
	}

	function handleIconClick( ev ) {
		var el = jQuery( ev.currentTarget );
		var row = el.closest( 'div.row' );
		var dev = parseInt( row.attr( 'id' ).replace( /^d/i, "" ) );
		var act = el.attr( 'id' );
		var t;

		switch ( act ) {
			case 'visibility':
				var vis = el.text() == "visibility";
				/* Changing the device property this way causes a Luup reload. So don't do that. We've got our own way. */
				/* api.setDeviceProperty( dev, 'invisible', vis ? 1 : 0, { persistent: true } ); */
				var devobj = api.getDeviceObject( dev );
				api.performActionOnDevice( devobj.id_parent, serviceId, "SetSwitchVisibility", { actionArguments: { DeviceNum: dev, Visibility: vis ? "0" : "1" } });
				el.text( vis ? "visibility_off" : "visibility" );
				break;

			case 'impulse':
				t = api.getDeviceState( dev, serviceId, "ImpulseTime" ) || "0";
				while (true) {
					t = prompt( 'Please enter pulse/reset time (secs, 0=normal operation):', t );
					if ( t == null ) break;
					var n = parseInt( t );
					if ( ! isNaN( n ) && n >= 0 ) {
						api.setDeviceStatePersistent( dev, serviceId, "ImpulseTime", String(n) );
						el.text( n == 0 ? "timer_off" : "timer" );
						break;
					}
				}
				break;

			case 'repeat':
				t = 0 !== parseInt( api.getDeviceState( dev, serviceId, "AlwaysUpdateStatus" ) || 0 );
				/* Set opposite icon and value */
				jQuery( 'i#repeat', row ).text( t ? 'repeat_one' : 'repeat' )
					.attr( 'title', t ? "Trigger only if status changes" : "Always trigger" );
				api.setDeviceStatePersistent( dev, serviceId, "AlwaysUpdateStatus", String(t ? 0 : 1) );
				break;

			default:
		}
	}

	function handleTextClick( ev ) {
		var el = jQuery( ev.currentTarget );
		var row = el.closest( 'div.row' );
		var dev = parseInt( row.attr( 'id' ).replace( /^d/i, "" ) );
		var subject = el.attr( 'id' ) == "vstext2" ? "Text2" : "Text1";
		var txt = api.getDeviceState( dev, "urn:upnp-org:serviceId:VSwitch1", subject ) || "";
		var newText = prompt( 'Enter new '+subject+' value:', txt );
		console.log( typeof(newText) + ":" + String(newText) );
		if ( newText != null ) {
			api.setDeviceStatePersistent( dev, "urn:upnp-org:serviceId:VSwitch1", subject, newText );
			jQuery( 'span#vstext' + ( subject == "Text2" ? "2" : "1" ), row ).text( newText );
		}
	}

	function handleNameClick( ev ) {
		var el = jQuery( ev.currentTarget );
		var row = el.closest( 'div.row' );
		var dev = parseInt( row.attr( 'id' ).replace( /^d/i, "" ) );
		var devobj = api.getDeviceObject( dev );
		var txt = devobj.name;
		while ( true ) {
			txt = prompt( 'Enter new switch name:', txt );
			if ( txt == null ) break;
			if ( txt.match( /^.+$/ ) ) {
				/* This causes a Luup reload, so don't do it this way. We have our own way. */
				/* api.setDeviceProperty( dev, 'name', txt, { persistent: true } ); */
				api.performActionOnDevice( devobj.id_parent, serviceId, "SetSwitchName", { actionArguments: { DeviceNum: dev, NewName: txt } });
				el.text( txt );
				break;
			}
		}
	}

	function updateStatus(pdev) {
		pdev = pdev || api.getCpanelDeviceId();
		var container = jQuery( "div#switchboardstatus div#devices" ).empty();

		var switches = getDevices( pdev );
		var row = jQuery('<div class="row headrow" />');
		row.append( '<div class="colhead col-xs-1 col-md-1" />' );
		row.append( '<div class="colhead col-xs-11 col-md-5">Device Name</div>' );
		row.append( '<div class="colhead col-xs-4 col-md-2">Options</div>' );
		row.append( '<div class="colhead col-xs-4 col-md-2">Text1</div>' );
		row.append( '<div class="colhead col-xs-4 col-md-2">Text2</div>' );
		container.append( row );

		jQuery.each( switches, function( ix, obj ) {
			row = jQuery('<div class="row devicerow" />');
			var el = jQuery( '<div class="col-xs-1 col-md-1 text-right" />' );
			var st = api.getDeviceState( obj.id, "urn:upnp-org:serviceId:SwitchPower1", "Status" ) || "0";
			el.append( jQuery( '<img id="state" src="https://www.toggledbits.com/assets/switchboard/switchboard-switch-' +
				( {"0":"off","1":"on","2":"x"}[st] || "x" ) + '.png" width="32" height="32" alt="switch state">' )
				.attr( 'title', 'Click to toggle state' )
			);
			row.append( el );
			row.append( jQuery( '<div class="vsname col-xs-11 col-md-5" />' ).text( obj.name + ' (#' + obj.id + ')' ).attr( 'title', 'Click to change name' ) );
			el = jQuery( '<div class="col-xs-4 col-md-2" />' );
			el.append( '<i id="visibility" class="material-icons md-btn" title="Toggle visibility">visibility</i>' );
			el.append( '<i id="impulse" class="material-icons md-btn" title="Set auto-reset timer">timer_off</i>' );
			if ( isOpenLuup ) {
				el.append( '<i id="repeat" class="material-icons md-btn" title="Trigger only if status changes">repeat_one</i>' );
			}
			row.append( el );
			var s = api.getDeviceState( obj.id, "urn:upnp-org:serviceId:VSwitch1", "Text1" );
			row.append( '<div class="col-xs-4 col-md-2"><span id="vstext1" class="vstext"/><i id="vstext1" class="vstext material-icons md-btn">create</i></div>' );
			jQuery( 'span#vstext1', row ).text( s || "" );
			s = api.getDeviceState( obj.id, "urn:upnp-org:serviceId:VSwitch1", "Text2" );
			row.append( '<div class="col-xs-4 col-md-2"><span id="vstext2" class="vstext"/><i id="vstext2" class="vstext material-icons md-btn">create</i></div>' );
			jQuery( 'span#vstext2', row ).text( s || "" );
			row.attr( 'id', 'd' + obj.id );
			container.append( row );

			if ( ( obj.invisible || "0" ) != "0" ) {
				jQuery( 'i#visibility', row ).text( 'visibility_off' );
			}
			st = parseInt( api.getDeviceState( obj.id, serviceId, "ImpulseTime" ) || 0 );
			if ( ! isNaN( st ) && st > 0 ) {
				jQuery( 'i#impulse', row ).text( 'timer' ).attr( 'title', 'Always trigger' );
			}
			st = 0 !== parseInt( api.getDeviceState( obj.id, serviceId, "AlwaysUpdateStatus" ) || 0 );
			if ( st ) {
				jQuery( 'i#repeat', row ).text( 'repeat' );
			}

			jQuery( 'img#state', row ).on( 'click.switchboard', handleStateClick );
			jQuery( 'i.md-btn', row ).on( 'click.switchboard', handleIconClick );
			jQuery( '.vstext', row ).attr( 'title', 'Click to edit' ).on( 'click.switchboard', handleTextClick );
			jQuery( 'div.vsname', row ).on( 'click.switchboard', handleNameClick );
		});
	}

	function onUIDeviceStatusChanged( args ) {
		if ( !inStatusPanel ) {
			return;
		}
		var pdev = api.getCpanelDeviceId();
		var ix = api.getDeviceObject( args.id );
		if ( ix && ix.id_parent == pdev ) {
			updateStatus( pdev );
		}
	}

	function waitForReload() {
		jQuery.ajax({
			url: api.getDataRequestURL(),
			data: {
				id: "status",
				DeviceNum: api.getCpanelDeviceId(),
				output_format: "json"
			},
			dataType: "json",
			timeout: 5000
		}).done( function( data, statusText, jqXHR ) {
			var key = "Device_Num_" + api.getCpanelDeviceId();
			if ( data[key] && -1 === parseInt( data[key].status ) ) {
				jQuery( 'div#tail button#addchild' ).prop( 'disabled', false );
				jQuery( 'div#tail div#notice' ).text("");
				setTimeout( updateStatus, 2000 );
			} else {
				jQuery( 'div#tail div#notice' ).append( "&ndash;" );
				setTimeout( waitForReload, 1000 );
			}
		}).fail( function( jqXHR, textStatus, errorThrown ) {
			jQuery( 'div#tail div#notice' ).append( "&bull;" );
			setTimeout( waitForReload, 2000 );
		});
	}

	function handleAddChildClick( ev ) {
		var el = jQuery( ev.currentTarget );
		var row = el.closest( 'div#tail' );
		var childType = jQuery( 'select#childtype', row ).val() || "";
		if ( "" !== childType ) {
			api.performActionOnDevice( api.getCpanelDeviceId(), serviceId, "AddChild", {
				actionArguments: { DeviceType: childType },
				onSuccess: function( xhr ) {
					el.prop( 'disabled', true );
					jQuery( 'div#notice', row ).text("Creating child... please wait while Luup reloads...");
					setTimeout( waitForReload, 5000 );
				},
				onFailure: function( xhr ) {
					alert( "An error occurred. Try again in a moment; Vera may be busy." );
				}
			} );
		} else {
			jQuery( 'div#notice', row ).text("Wählen Sie zuerst einen Typ!");
		}
	}

	function doStatusPanel()
	{
		console.log("doStatusPanel()");

		try {
			if ( ! initModule() ) {
				return;
			}

			/* Our styles. */
			var html = "<style>";
			html += 'div#switchboardstatus {}';
			html += 'div#switchboardstatus div.row { min-height: 40px; margin-top: 4px; margin-bottom: 4px; border-bottom: 1px dotted #006040; }';
			html += 'div#switchboardstatus div.vsname { font-size: 16px; }';
			html += 'div#switchboardstatus i.md-btn { margin-right: 4px; }';
			html += 'div#switchboardstatus i.vstext.md-btn { font-size: 18px; }';
			html += 'div#switchboardstatus div.headrow { color: white; font-size: 16px; font-weight: bold; line-height: 40px; background-color: #00a652; }';
			html += 'div#switchboardstatus div.colhead { }';
			html += "</style>";
			jQuery("head").append( html );

			html = '<div id="switchboardstatus" class="switchboardtab"></div>';
			html += footer();
			api.setCpanelContent( html );

			var container = jQuery( "div#switchboardstatus" );
			container.append( jQuery( '<div id="devices" />' ) );
			var br = jQuery( '<div id="tail" class="form-inline" />' );
			var sel = jQuery( '<select id="childtype" class="form-control form-control-sm" />' );
			sel.append( jQuery( '<option/>' ).val("").text('--choose type--') ).val( "" ); /* default */
			br.append( sel );
			br.append( '<button id="addchild" class="btn btn-md btn-primary">Create New Virtual Device</button>' );
			br.append( '<div id="notice" />' );
			container.append( br );

			/* Now, populate the menu */
			jQuery( 'button#addchild', container ).on( 'click.switchboard', handleAddChildClick ).prop( 'disabled', true );
			jQuery.ajax({
				url: api.getDataRequestURL(),
				data: {
					id: "lr_Switchboard",
					action: "getvtypes"
				},
				dataType: "json",
				timeout: 5000
			}).done( function( data, statusText, jqXHR ) {
				var hasOne = false;
				var childMenu = jQuery( 'div#tail select#childtype' );
				for ( var ch in data ) {
					if ( data.hasOwnProperty( ch ) ) {
						childMenu.append( jQuery( '<option/>' ).val( ch ).text( data[ch].name || ch ) );
						hasOne = true;
					}
				}
				if ( hasOne ) {
					jQuery( 'div#tail button#addchild' ).prop( 'disabled', false );
				}
			}).fail( function( jqXHR ) {
				alert( "There was an error loading configuration data. Vera may be busy; try again in a moment." );
			});

			api.registerEventHandler('on_ui_deviceStatusChanged', Switchboard1_UI7, 'onUIDeviceStatusChanged');
			inStatusPanel = true; /* Tell the event handler it's OK */

			updateStatus( api.getCpanelDeviceId() );
		}
		catch( e ) {
			alert( String(e) + "\n" + e.stack );
		}
	}


/** ***************************************************************************
 *
 * C L O S I N G
 *
 ** **************************************************************************/

	console.log("Initializing Switchboard1_UI7 module");

	myModule = {
		uuid: uuid,
		initModule: initModule,
		onBeforeCpanelClose: onBeforeCpanelClose,
		onUIDeviceStatusChanged: onUIDeviceStatusChanged,
		doStatusPanel: doStatusPanel
	};
	return myModule;
})(api, $ || jQuery);
