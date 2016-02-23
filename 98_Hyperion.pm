##############################################
# $Id: 
#
# Usage
# 
# define <name> Hyperion <IP or HOSTNAME> <PORT>
#
# Changelog
#
# V 0.10 2016-02-23 - initial beta version
############################################## 

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
    $hash->{UndefFn}    = 'Hyperion_Undef';
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
    
    if(int(@param) < 3)
	{
        return "too few parameters: define <name> Hyperion <IP> <PORT>";
    }
    
    $hash->{IP} = $param[2];
    $hash->{PORT} = $param[3];
    
	my $effectList = AttrVal($hash->{NAME}, "effects", "noArg");
	
	if(length($effectList) > 0)
	{
		$Hyperion_sets{'effect_g'} = $effectList;
	}
	
    return undef;
}

sub Hyperion_Undef($$)
{
    my ($hash, $arg) = @_; 
    # nothing to do
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
	my ($socket,$client_socket);
	my $data = "";
	
	# if(!defined($Hyperion_gets{$command}))
	# {
		# my @cList = keys %Hyperion_gets;
		# return "Unknown argument $command, choose one of " . join(" ", @cList);
	# }
	
	if($command ne "effectList")
	{
		my @cList = keys %Hyperion_gets;
		return "Unknown argument $command, choose one of " . join(" ", @cList);
	}
	
	$socket = new IO::Socket::INET (
	PeerHost => $remote_ip,
	PeerPort => $remote_port,
	Proto => 'tcp',
	); 

	if (!$socket) { 
		Log3 $name, 3, "$name: ERROR. Can't open socket to $remote_ip $remote_port";
		$hash->{STATE} = "ERROR. Can't open socket to $remote_ip $remote_port";
		$hash->{last_command} = "ERROR. Can't open socket to $remote_ip $remote_port";
		return undef;
	}
	
	$hash->{last_command} = "{\"command\":\"serverinfo\"}\n";
	$socket->send("{\"command\":\"serverinfo\"}\n");
	$data = <$socket>;
	
	$socket->close();
    my $decoded_json = JSON->new->decode($data);
	my $attribut = "";
	for (@{ $decoded_json->{info}->{effects} })
	{
		if(length($attribut) == 0)
		{
			$attribut = $_->{name};
		}
		else
		{
			$attribut = $attribut . "," . $_->{name};
		}
		Log3 $name, 4, "$name: Effect: $_->{name}";
	}
	
	$attribut =~ s/ /_/g;
	$attr{$name}{"effects"} = $attribut;
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
	my $duration = AttrVal($name, "duration", "");
	
	if ($count >= 4)
	{
		$duration = shift @param;
	}
	if(length($duration) > 0)
	{
		
		$duration = ",\"duration\":".$duration."000";
	}
	my $priority = AttrVal($name, "priority", "500");
	if ($count >= 5)
	{
		$priority = shift @param;
	}
	if(length($priority) > 0)
	{
		$priority = ",\"priority\":$priority";
	}
	
	my $remote_ip = $hash->{IP};
	my $remote_port = $hash->{PORT};
	my ($socket,$client_socket);
	my $data;
	my $recv_data;
	my $state;
	
	if ($command eq "?")
	{
		return join(" ", map { "$_:$Hyperion_sets{$_}" } keys %Hyperion_sets);
	}
	if($command eq "loadEffects")
	{
		my $effectList = AttrVal($name, "effects", "noArg");
		
		if(length($effectList) > 0)
		{
			$Hyperion_sets{'effect_g'} = $effectList;
		}
		return undef;
	}

	$socket = new IO::Socket::INET (
	PeerHost => $remote_ip,
	PeerPort => $remote_port,
	Proto => 'tcp',
	); 

	if (!$socket) { 
		Log3 $name, 3, "$name: ERROR. Can't open socket to $remote_ip $remote_port";
		$hash->{STATE} = "ERROR. Can't open socket to $remote_ip $remote_port";
		$hash->{last_command} = "ERROR. Can't open socket to $remote_ip $remote_port";
		return undef;
	};
	
	if($command eq "color" or $command eq "color_g")
	{
		my( $r, $g, $b ) = Color::hex2rgb($value);
		$data = "{\"color\":[$r,$g,$b],\"command\":\"color\"$priority$duration}";
		Log3 $name, 4, "$name: set color: '$data'";
		$state = "Color $value";
	}
	elsif($command eq "effect" or $command eq "effect_g")
	{
		$value =~ s/_/ /;
		$data = "{\"effect\":{\"name\":\"$value\"},\"command\":\"effect\"$priority$duration}";
		Log3 $name, 4, "$name: set effect: '$data'";
		$state = "Effect $value";
	}
	elsif($command eq "clear")
	{
		$data = "{\"command\":\"clearall\"}";
		Log3 $name, 4, "$name: clearall";
		$state = "Cleared";
	}
	else
	{
		Log3 $name, 4, "$name: set $command to '$value'";
	}
	
	$socket->send("$data\n");
	$socket->recv($recv_data,1024);
	
	$recv_data =~ s/\s+$//;
	if($recv_data eq "{\"success\":true}")
	{
		$hash->{STATE} = $state;
	}
	else
	{
		$hash->{STATE} = "ERROR: '$recv_data' | $data";
	}
	
	$hash->{last_command} = $data;
	$socket->close();
	
	return undef;
}

sub Hyperion_Attr(@)
{
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	if($cmd eq "set")
	{
        if($attr_name eq "priority")
		{
			if($attr_value !~ /^[0-9]{1,}$/)
			{
			    my $err = "Invalid argument $attr_value to $attr_name. Must be a number.";
			    Log3 $name, 3, "Hyperion: ".$err;
			    return $err;
			}
		} 
		elsif($attr_name eq "effects")
		{
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
</ul>

=end html_DE

=cut