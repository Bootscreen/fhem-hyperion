#####################################################################################
# $Id: 
#
# Usage
# 
# define <name> Hyperion <IP or HOSTNAME> <PORT>
#
# Changelog
#
# V 0.10 2016-02-23  -  initial beta version
# V 0.11 2016-02-23  -  fixed commandref formating
# V 0.20 2016-02-24  -  fixed effect_g not loaded after reload
#                       changed attribute effects, no underscore required anymore
#                       added error handling for unsupported commands
#                       optimized some code
#                       removed duplicated and unnecessary code
# V 0.30 2016-02-25  -  added readings
#
#####################################################################################

package main;

use strict;
use warnings;
use Color;
use IO::Socket;
use IO::Socket::INET;
use JSON;

my %Hyperion_sets = ( "color" => "textField", "color_g" => "colorpicker,RGB", "effect" => "textField", "effect_g" => "noArg", "clear" => "noArg", "loadEffects" => "noArg");
my %Hyperion_gets = ( "effectList:noArg" => "");

sub Hyperion_Initialize($)
{
    my ($hash) = @_;

    $hash->{DefFn}      = 'Hyperion_Define';
    $hash->{SetFn}      = 'Hyperion_Set';
    $hash->{GetFn}      = 'Hyperion_Get';
    $hash->{AttrFn}     = 'Hyperion_Attr';

    $hash->{AttrList} =
			"priority " .
			"effects " . 
			"duration " . 
			$readingFnAttributes;
}

sub Hyperion_Define($$)
{
    my ($hash, $def) = @_;
    my @param = split('[ \t]+', $def);
    
    if(int(@param) != 4)
	{
        return "too few parameters: define <name> Hyperion <IP> <PORT>";
    }
    
    $hash->{IP} = $param[2];
    $hash->{PORT} = $param[3];
    
    return undef;
}

sub Hyperion_Get($@)
{
	my ($hash, @param) = @_;
	
	return '"get Hyperion" needs at least one argument' if (int(@param) < 2);
	
	my $name = shift @param;
	my $command = shift @param;
	
	my $remote_ip = $hash->{IP};
	my $remote_port = $hash->{PORT};
	my $socket;
	my $data = "";
	my $decoded_json = "";
    
	if($command ne "effectList")
	{
		return "Unknown argument $command for $name, choose one of " . join(", ", sort keys %Hyperion_gets);
	}
	
	$socket = new IO::Socket::INET (
        PeerHost => $remote_ip,
        PeerPort => $remote_port,
        Proto => 'tcp',
	); 

	if (!$socket) { 
		Log3 $name, 3, "$name: ERROR. Can't open socket to $remote_ip $remote_port";
        readingsBeginUpdate($hash);
        readingsBulkUpdate($hash,"last_result","Can't open socket to $remote_ip $remote_port");
        readingsBulkUpdate($hash,"last_command","{\"command\":\"serverinfo\"}");
        readingsBulkUpdate($hash,"state","ERROR",1);
        readingsEndUpdate($hash, 0);
		return undef;
	}
	
	$socket->send("{\"command\":\"serverinfo\"}\n");
	$data = <$socket>;
	$socket->close();
    if (index($data, "\"success\":false") == -1)
    {
        $decoded_json = JSON->new->decode($data);
        $attr{$name}{"effects"} = join(",", map { "$_->{name}"} @{ $decoded_json->{info}->{effects}});
        readingsBeginUpdate($hash);
        readingsBulkUpdate($hash,"last_command","{\"command\":\"serverinfo\"}");
        readingsBulkUpdate($hash,"state","success");
        readingsEndUpdate($hash, 0);
    }
    else
    {
        readingsBeginUpdate($hash);
        readingsBulkUpdate($hash,"last_result","$data");
        readingsBulkUpdate($hash,"last_command","{\"command\":\"serverinfo\"}");
        readingsBulkUpdate($hash,"state","ERROR",1);
        readingsEndUpdate($hash, 0);
    }
    
	return undef;
}

sub Hyperion_Set($@)
{
	my ($hash, @param) = @_;
	
	my $count = int(@param);
	
	return '"set Hyperion" needs at least one argument' if ($count < 2);
	
	my $name = shift @param;
	my $command = shift @param;
	my $value = shift @param;
	my $duration = AttrVal($name, "duration", "0");
    my $secounds = 0;
	if ($count >= 4)
	{
		$duration = shift @param;
	}
	if($duration > 0)
	{
        $secounds = $duration;
		$duration = ",\"duration\":".$duration."000";
	}
    
	my $priority = AttrVal($name, "priority", "500");
	if ($count >= 5)
	{
		$priority = shift @param;
	}
	
	my $remote_ip = $hash->{IP};
	my $remote_port = $hash->{PORT};
	my $socket;
	my $data;
	my $recv_data;
	my $state;
	
	if($command eq "loadEffects" or $command eq "?")
	{
        if(length($hash->{last_command}) > 0)
        {
            delete $hash->{last_command};
        }
    
		my $effectList = AttrVal($name, "effects", "noArg");
		
		if(length($effectList) > 0)
		{
            $effectList =~ s/ /_/g;
			$Hyperion_sets{'effect_g'} = $effectList;
		}
		return join(" ", map { "$_:$Hyperion_sets{$_}" } keys %Hyperion_sets);
	}
	elsif($command eq "color" or $command eq "color_g")
	{
		my( $r, $g, $b ) = Color::hex2rgb($value);
        $command = "color";
		$data = "{\"color\":[$r,$g,$b],\"command\":\"$command\",\"priority\":$priority$duration}";
		Log3 $name, 4, "$name: set color: '$data'";
		$state = "Color $value";
	}
	elsif($command eq "effect" or $command eq "effect_g")
	{
		$value =~ s/_/ /g;
        $command = "effect";
		$data = "{\"effect\":{\"name\":\"$value\"},\"command\":\"$command\",\"priority\":$priority$duration}";
		Log3 $name, 4, "$name: set effect: '$data'";
		$state = "Effect $value";
	}
	elsif($command eq "clear")
	{
        $secounds = 0;
		$data = "{\"command\":\"clearall\"}";
		Log3 $name, 4, "$name: clearall";
		$state = "Cleared";
	}
	else
	{
		return "Unknown argument $command for $name, choose one of " . join(", ", sort keys %Hyperion_sets);
	}

	$socket = new IO::Socket::INET (
        PeerHost => $remote_ip,
        PeerPort => $remote_port,
        Proto => 'tcp',
	); 

	if (!$socket) { 
		Log3 $name, 3, "$name: ERROR. Can't open socket to $remote_ip $remote_port";
        readingsBeginUpdate($hash);
        readingsBulkUpdate($hash,"last_result","Can't open socket to $remote_ip $remote_port");
        readingsBulkUpdate($hash,"last_command",$data);
        readingsBulkUpdate($hash,"last_type",$command);
        readingsBulkUpdate($hash,"last_value",$value);
        readingsBulkUpdate($hash,"last_duration", $secounds);
        readingsBulkUpdate($hash,"last_priority",$priority);
        readingsBulkUpdate($hash,"state","ERROR",1);
        readingsEndUpdate($hash, 0);
		return undef;
	};
	
	$socket->send("$data\n");
	$socket->recv($recv_data,1024);
	
	$recv_data =~ s/\s+$//;
    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash,"last_result",$recv_data);
    readingsBulkUpdate($hash,"last_command",$data);
    readingsBulkUpdate($hash,"last_type",$command);
    readingsBulkUpdate($hash,"last_value",$value);
    readingsBulkUpdate($hash,"last_duration", $secounds);
    readingsBulkUpdate($hash,"last_priority",$priority);
	if($recv_data eq "{\"success\":true}")
	{
        if($command eq "clear")
        {
            readingsBulkUpdate($hash,"state","success",1);  
        }
        elsif($secounds > 0)
        {
            readingsBulkUpdate($hash,"state","started",1);
            InternalTimer(gettimeofday()+$secounds, "Hyperion_GetUpdate", $hash, 0);
        }
        else
        {
            readingsBulkUpdate($hash,"state","started infinity",1);
        }
	}
	else
	{
        readingsBulkUpdate($hash,"state","ERROR",1);
	}
    readingsEndUpdate($hash, 0);
	
	$socket->close();
	
	return undef;
}

sub Hyperion_GetUpdate(@)
{
    my ($hash) = @_;
    
    readingsSingleUpdate($hash,"state","finished",1);
	Log3 "test", 3, "test";
	return undef;
}

sub Hyperion_Attr(@)
{
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	if($cmd eq "set")
	{
        if($attr_name eq "priority" or $attr_name eq "duration")
		{
			if($attr_value !~ /^[0-9]{1,}$/)
			{
			    my $err = "Invalid value ($attr_value) for attribute $attr_name. Must be a number.";
			    return $err;
			}
		} 
		elsif($attr_name eq "effects")
		{
            $attr_value =~ s/ /_/g;
			$Hyperion_sets{'effect_g'} = $attr_value;		
		}
	}
	return undef;
}

1;

=pod
=begin html

<a name="Hyperion"></a>
<h3>Hyperion</h3>
<ul>
    With <i>Hyperion</i> it is possible to switch the color or start an effect on a hyperion server.<br>
	The Hyperion Server must have enabled the JSON Server.<br>
  <br>
  <a name="Hyperion_define"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; Hyperion &lt;IP or HOSTNAME&gt; &lt;PORT&gt;</code>    
  </ul>
  <br>
  <a name="Hyperion_set"></a>
  <p><b>Set &lt;required&gt; [optional] </b></p>
  <ul>
    <li>
      <a name="clear">clear</a><br>
      clear all colors and effects
    </li>
    <li>
      <a name="color">color &lt;RRGGBB&gt; [duration] [priority]</a><br>
      send Color in RGB Hex Format with optional duration and priority
    </li>
    <li>
      <a name="color_g">color_g</a><br>
      send Color in RGB Hex Format with the colorpicker
    </li>
    <li>
      <a name="effect">effect &lt;effect&gt; [duration] [priority]</a><br>
      send effect (replace Blanks with Underscore, look at 'get <name> effectList') with optional duration and priority
    </li>
    <li>
      <a name="effect_g">effect_g</a><br>
      send effect with the dropdown list
    </li>
    <li>
      <a name="loadEffects">loadEffects</a><br>
      if effect_g has no dropdown you can manualy load the dropdown from the effects attribute
    </li>
  </ul>  
  <br>
  <a name="Hyperion_get"></a>
  <p><b>Get</b></p>
  <ul>    
    <li>
      <a name="effectList">effectList</a><br>
      get a List of all effects from the Hyperion Server and save it as the Attribute effects
    </li>
  </ul>
  <br>
  <a name="Hyperion_Attr"></a>
  <b>Attributes</b>
  <ul>
    <li><a name="effects">effects</a><br>
        list of effects on the Hyperion Server for the effect_g dropdown list
    </li>
    <li><a name="duration">duration</a><br>
        standard duration, if not set it's infinity
    </li>
    <li><a name="priority">priority</a><br>
        standard priority, if not set it's 500
    </li>
  </ul>
  <a name="Hyperion_Read"></a>
  <b>Readings</b>
  <ul>
    <li><a name="state">state</a><br>
        shows the state of the last_command:
        <ul>
            <li>success: when get command or set clear successful</li>
            <li>started infinity: when set effect or color without duration</li>
            <li>started: when set effect or color with duration</li>
            <li>finished: when set effect or color is finished after duration</li>
        </ul>
    </li>
    <li><a name="last_result">last_result</a><br>
        shows the last answer of hyperion
    </li>
    <li><a name="last_command">last_command</a><br>
        shows the full last sended command
    </li>
    <li><a name="last_type">last_type</a><br>
        shows the last sended type
    </li>
    <li><a name="last_value">last_value</a><br>
        shows the last sended type parameter
    </li>
    <li><a name="last_duration">last_duration</a><br>
        shows the last duration
    </li>
    <li><a name="last_priority">last_priority</a><br>
        shows the last priority
    </li>
  </ul>
</ul>

=end html

=begin html_DE

<a name="Hyperion"></a>
<h3>Hyperion</h3>
<ul>
    Mit <i>Hyperion</i> ist es möglich Farbe oder Effekte eines Hyperion Servers zu starten bzw. zu ändern.<br>
	Der Hyperion Server muss dazu den JSON Server aktiviert haben.<br>
  <br>
  <a name="Hyperion_define"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; Hyperion &lt;IP oder HOSTNAME&gt; &lt;PORT&gt;</code>    
  </ul>
  <br>
  <a name="Hyperion_set"></a>
  <p><b>Set &lt;required&gt; [optional] </b></p>
  <ul>
    <li>
      <a name="clear">clear</a><br>
      löscht alle Farben und Effekte
    </li>
    <li>
      <a name="color">color &lt;RRGGBB&gt; [Dauer] [Priorität]</a><br>
      sendet die Farbe in RGB Hex Format mit optionaler Dauer und Priorität
    </li>
    <li>
      <a name="color_g">color_g</a><br>
      sendet die Farbe in RGB Hex Format aus dem Colorpicker
    </li>
    <li>
      <a name="effect">effect &lt;effect&gt; [Dauer] [Priorität]</a><br>
      startet den Effekt (Leerzeichen müssen durch Unterstriche ersetzt werden, siehe dazu 'get &lt;name&gt; effectList') mit optionaler Dauer und Priorität
    </li>
    <li>
      <a name="effect_g">effect_g</a><br>
      startet den Effekt aus der Dropdown Liste
    </li>
    <li>
      <a name="loadEffects">loadEffects</a><br>
      Lädt die Effekte aus dem Attribut effects in die Dropdown Liste für effect_g
    </li>
  </ul>  
  <br>
  <a name="Hyperion_get"></a>
  <p><b>Get</b></p>
  <ul>    
    <li>
      <a name="effectList">effectList</a><br>
      holt eine Liste von Effekten vom Hyperion Server und speichert diese im Attribut effects
    </li>
  </ul>
  <br>
  <a name="Hyperion_Attr"></a>
  <b>Attributes</b>
  <ul>
    <li><a name="effects">effects</a><br>
        Liste von Effekten für die Dropdown Liste effect_g
    </li>
    <li><a name="duration">duration</a><br>
        Standard Dauer, wenn nicht gesetzt ist die Dauer unendlich
    </li>
    <li><a name="priority">priority</a><br>
        Standard Priorität, wenn nicht gesetzt ist die Priorität 500
    </li>
  </ul>
  <a name="Hyperion_Read"></a>
  <b>Readings</b>
  <ul>
    <li><a name="state">state</a><br>
        zeigt den Status von last_command:
        <ul>
            <li>success: wenn get oder set clear erfoglreich</li>
            <li>started infinity: wenn set effect oder color ohne Dauer gestartet</li>
            <li>started: wenn set effect oder color mit Dauer gestartet</li>
            <li>finished: wenn set effect oder color mit Dauer beendet</li>
        </ul>
    </li>
    <li><a name="last_result">last_result</a><br>
        zeigt die letzte Antwort von hyperion
    </li>
    <li><a name="last_command">last_command</a><br>
        zeigt den zuletzt gesendeten Befehl 
    </li>
    <li><a name="last_type">last_type</a><br>
        zeigt den zuletzt gesendeten Typ 
    </li>
    <li><a name="last_value">last_value</a><br>
        zeigt den zuletzt gesendeten Typ-Parameter
    </li>
    <li><a name="last_duration">last_duration</a><br>
        zeigt den zuletzt gesendete Dauer
    </li>
    <li><a name="last_priority">last_priority</a><br>
        zeigt den zuletzt gesendete Priorität
    </li>
  </ul>
</ul>

=end html_DE

=cut