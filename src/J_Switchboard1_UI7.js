//# sourceURL=J_Switchboard_UI7.js
/**
 * J_Switchboard1_UI7.js
 * Configuration interface for Switchboard
 *
 * Copyright 2019 Patrick H. Rigney, All Rights Reserved.
 * This file is part of Switchboard. For license information, see LICENSE at https://github.com/toggledbits/Switchboard
 */
/* globals api,jQuery,$,MultiBox */

//"use strict"; // fails on UI7, works fine with ALTUI

var Switchboard1_UI7 = (function(api, $) {

    /* unique identifier for this plugin... */
    var uuid = 'fabe8224-2341-11e9-8762-74d4351650de'; /* 2019-01-28 Switchboard */

    var myModule = {};

    var serviceId = "urn:toggledbits-com:serviceId:Switchboard1";
    // var deviceType = "urn:schemas-toggledbits-com:device:Switchboard:1";

    var inStatusPanel = false;
    // var isOpenLuup = false;
    var isALTUI = ( "undefined" !== typeof(MultiBox) );

    /* Closing the control panel. */
    function onBeforeCpanelClose(args) {
        inStatusPanel = false;
    }

    /* Return footer */
    function footer() {
        var html = '';
        return html;
    }

    function initModule() {
        api.registerEventHandler('on_ui_cpanel_before_close', Switchboard1_UI7, 'onBeforeCpanelClose');
        inStatusPanel = false;

        /* Load material design icons */
        jQuery("head").append('<link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">');
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
        var dev = parseInt( row.attr( 'id' ) );
        if ( api.getDeviceProperty( dev, "model" ) == "Switchboard Virtual Tri-state Switch" ) {
            var st = api.getDeviceState( dev, "urn:upnp-org:serviceId:SwitchPower1", "Status" ) || "2";
            st = ( parseInt( st ) + 1 ) % 3;
            api.performActionOnDevice( dev, "urn:upnp-org:serviceId:SwitchPower1", "SetTarget", { actionArguments: { newTargetValue: String(st) } } );
        } else {
            api.performActionOnDevice( dev, "urn:micasaverde-com:serviceId:HaDevice1", "ToggleState", { actionArguments: {} });
        }
    }

    function handleIconClick( ev ) {
        var el = jQuery( ev.currentTarget );
        var row = el.closest( 'div.row' );
        var dev = parseInt( row.attr( 'id' ) );
        var act = el.attr( 'id' );

        switch ( act ) {
            case 'visibility':
                var vis = el.text() == "visibility";
                api.setDeviceProperty( dev, 'invisible', vis ? 1 : 0, { persistent: true } );
                /*
                var devobj = api.getDeviceObject( dev );
                api.performActionOnDevice( devobj.id_parent, serviceId, "SetSwitchVisibility", { actionArguments: { DeviceNum: dev, Visibility: vis ? "0" : "1" } });
                */
                el.text( vis ? "visibility_off" : "visibility" );
                break;

            case 'impulse':
                var t = api.getDeviceState( dev, serviceId, "ImpulseTime" ) || "0";
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

            default:
        }
    }

    function handleTextClick( ev ) {
        var el = jQuery( ev.currentTarget );
        var row = el.closest( 'div.row' );
        var dev = parseInt( row.attr( 'id' ) );
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
        var dev = parseInt( row.attr( 'id' ) );
        var devobj = api.getDeviceObject( dev );
        var txt = devobj.name;
        while ( true ) {
            txt = prompt( 'Enter new switch name:', txt );
            if ( txt == null ) break;
            if ( txt.match( /^.+$/ ) ) {
                api.setDeviceProperty( dev, 'name', txt, { persistent: true } );
                /*
                api.performActionOnDevice( devobj.id_parent, serviceId, "SetSwitchName", { actionArguments: { DeviceNum: dev, NewName: txt } });
                */
                el.text( txt );
                break;
            }
        }
    }

    function updateStatus(pdev) {
        var container = jQuery( "div#switchboardstatus" ).empty();

        var switches = getDevices( pdev );
        var row = jQuery('<div class="row headrow" />');
        row.append( '<div class="colhead col-xs-1 col-md-1" />' );
        row.append( '<div class="colhead col-xs-11 col-md-5">Device Name</div>' );
        row.append( '<div class="colhead col-xs-4 col-md-2">Options</div>' );
        row.append( '<div class="colhead col-xs-4 col-md-2">Text1</div>' );
        row.append( '<div class="colhead col-xs-4 col-md-2">Text2</div>' );
        container.append( row );
        
        jQuery.each( switches, function( ix, obj ) {
            row = jQuery('<div class="row" />');
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
            row.append( el );
            var s = api.getDeviceState( obj.id, "urn:upnp-org:serviceId:VSwitch1", "Text1" );
            row.append( '<div class="col-xs-4 col-md-2"><span id="vstext1" class="vstext"/><i id="vstext1" class="vstext material-icons md-btn">create</i></div>' );
            jQuery( 'span#vstext1', row ).text( s || "" );
            s = api.getDeviceState( obj.id, "urn:upnp-org:serviceId:VSwitch1", "Text2" );
            row.append( '<div class="col-xs-4 col-md-2"><span id="vstext2" class="vstext"/><i id="vstext2" class="vstext material-icons md-btn">create</i></div>' );
            jQuery( 'span#vstext2', row ).text( s || "" );
            row.attr( 'id', obj.id );
            container.append( row );

            if ( ( obj.invisible || "0" ) != "0" ) {
                jQuery( 'i#visibility', row ).text( 'visibility_off' );
            }
            st = parseInt( api.getDeviceState( obj.id, serviceId, "ImpulseTime" ) || 0 );
            if ( ! isNaN( st ) && st > 0 ) {
                jQuery( 'i#impulse', row ).text( 'timer' );
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
        var doUpdate = false;
        for ( var k=0; k<(args.states || []).length; ++k ) {
            if ( args.states[k].service == "urn:upnp-org:serviceId:SwitchPower1" ||
                args.states[k].service == "urn:upnp-org:serviceId:VSwitch1" ) {
                var ix = api.getDeviceObject( args.id );
                if ( ix.id_parent == pdev ) {
                    doUpdate = true;
                    break;
                }
            }
        }
        if ( doUpdate ) {
            updateStatus( pdev );
        }
    }

    function doStatusTab()
    {
        console.log("doStatusPanel()");

        try {
            initModule();

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
        doStatusTab: doStatusTab
    };
    return myModule;
})(api, $ || jQuery);
