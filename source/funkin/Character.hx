package funkin;

/**
	The character class initialises any and all characters that exist within gameplay. For now, the character class will
	stay the same as it was in the original source of the game. I'll most likely make some changes afterwards though!
**/
import base.*;
import dependency.FNFSprite;
import flixel.FlxG;
import flixel.addons.util.FlxSimplex;
import flixel.animation.FlxBaseAnimation;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxSort;
import funkin.Section.SwagSection;
import funkin.Song.SwagSong;
import funkin.background.TankmenBG;
import funkin.ui.HealthIcon;
import haxe.Json;
import openfl.Assets;
import openfl.utils.Assets as OpenFlAssets;
import states.PlayState;
import states.subStates.GameOverSubState;
import sys.FileSystem;
import sys.io.File;

using StringTools;

typedef PsychEngineChar =
{
	var animations:Array<PsychAnimArray>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;
	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Float>;
}

typedef PsychAnimArray =
{
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
}

class Character extends FNFSprite
{
	public var character:String;

	public var curCharacter:String = 'bf';

	public var holdTimer:Float = 0;

	public var icon:String;

	public var animationNotes:Array<Dynamic> = [];
	public var positionArray:Array<Float> = [0, 0];
	public var barColor:Array<Float> = [];

	public var characterScales:Array<Float> = [0, 0];
	public var characterCamOffsets:Array<Float> = [0, 0];

	public var debugMode:Bool = false;
	public var isPlayer:Bool = false;
	public var quickDancer:Bool = false;

	public var scriptArray:Array<ScriptHandler> = [];

	// FOR PSYCH COMPATIBILITY
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false; // Character use "danceLeft" and "danceRight" instead of "idle"
	public var skipDance:Bool = false;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var singDuration:Float = 4; // Multiplier of how long a character holds the sing pose

	public function new(?x:Float = 0, ?y:Float = 0, ?isPlayer:Bool = false, ?character:String = 'bf')
	{
		super(x, y);
		this.isPlayer = isPlayer;

		setCharacter(x, y, character);
	}

	public function setCharacter(x:Float, y:Float, character:String):Character
	{
		this.character = character;
		curCharacter = character;

		switch (curCharacter)
		{
			case 'pico-speaker':
				skipDance = true;
				loadMappedAnims();
				playAnim("shoot1");
		}

		var psychChar = FileSystem.exists(Paths.getPreloadPath('characters/$character/' + character + '.json'));

		switch (curCharacter)
		{
			// hardcoded (example, in case you want to hardcode characters)
			/*
				case 'bf-og':
					frames = Paths.getSparrowAtlas('characters/base/BOYFRIEND');
					animation.addByPrefix('idle', 'BF idle dance', 24, false);
					animation.addByPrefix('singUP', 'BF NOTE UP0', 24, false);
					animation.addByPrefix('singLEFT', 'BF NOTE LEFT0', 24, false);
					animation.addByPrefix('singRIGHT', 'BF NOTE RIGHT0', 24, false);
					animation.addByPrefix('singDOWN', 'BF NOTE DOWN0', 24, false);
					animation.addByPrefix('singUPmiss', 'BF NOTE UP MISS', 24, false);
					animation.addByPrefix('singLEFTmiss', 'BF NOTE LEFT MISS', 24, false);
					animation.addByPrefix('singRIGHTmiss', 'BF NOTE RIGHT MISS', 24, false);
					animation.addByPrefix('singDOWNmiss', 'BF NOTE DOWN MISS', 24, false);
					animation.addByPrefix('hey', 'BF HEY', 24, false);
					animation.addByPrefix('scared', 'BF idle shaking', 24);
					animation.addByPrefix('firstDeath', "BF dies", 24, false);
					animation.addByPrefix('deathLoop', "BF Dead Loop", 24, true);
					animation.addByPrefix('deathConfirm', "BF Dead confirm", 24, false);
					playAnim('idle');
					flipX = true;
			 */
			default:
				if (psychChar)
					generatePsychChar();
				generateBaseChar();
		}

		dance();

		return this;
	}

	override function update(elapsed:Float)
	{
		/**
		 * Special Animations Code.
		 * @author: Shadow_Mario_
		**/
		if (heyTimer > 0)
		{
			heyTimer -= elapsed;
			if (heyTimer <= 0)
			{
				if (specialAnim && animation.curAnim.name == 'hey' || animation.curAnim.name == 'cheer')
				{
					specialAnim = false;
					dance();
				}
				heyTimer = 0;
			}
		}
		else if (specialAnim && animation.curAnim.finished)
		{
			specialAnim = false;
			dance();
		}

		if (!isPlayer)
		{
			if (animation.curAnim.name.startsWith('sing'))
			{
				holdTimer += elapsed;
			}

			if (holdTimer >= Conductor.stepCrochet * 0.0011 * singDuration)
			{
				dance();
				holdTimer = 0;
			}
		}

		switch (curCharacter)
		{
			case 'pico-speaker':
				if (animationNotes.length > 0 && Conductor.songPosition > animationNotes[0][0])
				{
					var noteData:Int = 1;
					if (animationNotes[0][1] > 2)
						noteData = 3;

					noteData += FlxG.random.int(0, 1);
					playAnim('shoot' + noteData, true);
					animationNotes.shift();
				}
				if (animation.curAnim.finished)
					playAnim(animation.curAnim.name, false, false, animation.curAnim.frames.length - 3);
		}

		var curCharSimplified:String = simplifyCharacter();

		if (animation.curAnim != null)
			switch (curCharSimplified)
			{
				case 'gf':
					if (animation.curAnim.name == 'hairFall' && animation.curAnim.finished)
						playAnim('danceRight');
					if ((animation.curAnim.name.startsWith('sad')) && (animation.curAnim.finished))
						playAnim('danceLeft');
			}

		super.update(elapsed);
	}

	var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance(?forced:Bool = false)
	{
		if (!debugMode && !skipDance && animation.curAnim != null)
		{
			var curCharSimplified:String = simplifyCharacter();
			switch (curCharSimplified)
			{
				case 'gf':
					if ((!animation.curAnim.name.startsWith('hair')) && (!animation.curAnim.name.startsWith('sad')))
					{
						danced = !danced;

						if (danced)
							playAnim('danceRight', forced);
						else
							playAnim('danceLeft', forced);
					}
				default:
					// Left/right dancing, think Skid & Pump
					if (animation.getByName('danceLeft') != null && animation.getByName('danceRight') != null)
					{
						danced = !danced;
						if (danced)
							playAnim('danceRight', forced);
						else
							playAnim('danceLeft', forced);
					}
					else
						playAnim('idle', forced);
			}
		}
	}

	override public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		specialAnim = false;
		if (animation.getByName(AnimName) != null)
			super.playAnim(AnimName, Force, Reversed, Frame);

		if (curCharacter == 'gf')
		{
			if (AnimName == 'singLEFT')
				danced = true;
			else if (AnimName == 'singRIGHT')
				danced = false;

			if (AnimName == 'singUP' || AnimName == 'singDOWN')
				danced = !danced;
		}
	}

	public function simplifyCharacter():String
	{
		var base = curCharacter;

		if (base.contains('-'))
			base = base.substring(0, base.indexOf('-'));

		return base;
	}

	function loadMappedAnims()
	{
		var sections:Array<SwagSection> = Song.loadFromJson('picospeaker', PlayState.SONG.song.toLowerCase()).notes;
		for (section in sections)
		{
			for (note in section.sectionNotes)
			{
				animationNotes.push(note);
			}
		}
		TankmenBG.animationNotes = animationNotes;
		animationNotes.sort(sortAnims);
	}

	function sortAnims(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	function generateBaseChar()
	{
		var path:String = Paths.getPreloadPath('characters/$curCharacter/config.hxs');

		/* gonna try and fix psych chars first
			#if MODS_ALLOWED
			if (!FileSystem.exists(path))
			#else
			if (!Assets.exists(path))
			#end
			{
				path = Paths.getPreloadPath('characters/bf/config.hxs');
		}*/

		var scripts:Array<String> = [path];

		#if MODS_ALLOWED
		scripts.insert(0, Paths.getModPath('characters/$curCharacter', 'config', 'hxs'));
		#end

		var pushedScripts:Array<String> = [];

		for (i in scripts)
		{
			if (FileSystem.exists(i) && !pushedScripts.contains(i))
			{
				var script:ScriptHandler = new ScriptHandler(i);

				if (script.interp == null)
				{
					trace("Something terrible occured! Skipping.");
					continue;
				}

				scriptArray.push(script);
				pushedScripts.push(i);
			}
		}

		// trace(interp, script);
		set('addByPrefix', function(name:String, prefix:String, ?frames:Int = 24, ?loop:Bool = false)
		{
			animation.addByPrefix(name, prefix, frames, loop);
		});

		set('addByIndices', function(name:String, prefix:String, indices:Array<Int>, ?frames:Int = 24, ?loop:Bool = false)
		{
			animation.addByIndices(name, prefix, indices, "", frames, loop);
		});

		set('addOffset', function(?name:String = "idle", ?x:Float = 0, ?y:Float = 0)
		{
			addOffset(name, x, y);
			if (name == 'idle')
				positionArray = [x, y];
		});

		set('setSingDuration', function(amount:Int)
		{
			singDuration = amount;
		});

		set('set', function(name:String, value:Dynamic)
		{
			Reflect.setProperty(this, name, value);
		});

		set('setCameraOffsets', function(?x:Float = 0, ?y:Float = 0)
		{
			characterCamOffsets = [x, y];
		});

		set('setScale', function(?x:Float = 1, ?y:Float = 1)
		{
			characterScales = [x, y];
			scale.set(characterScales[0], characterScales[1]);
		});

		set('setIcon', function(swag:String = 'face') icon = swag);

		set('quickDancer', function(quick:Bool = false)
		{
			quickDancer = quick;
		});

		set('setBarColor', function(rgb:Array<Float>)
		{
			if (barColor != null)
				barColor = rgb;
			else
				barColor = [161, 161, 161];
			return true;
		});

		set('setDeathChar', function(char:String = 'bf-dead', lossSfx:String = 'fnf_loss_sfx', song:String = 'gameOver', confirmSound:String = 'gameOverEnd', bpm:Int)
		{
			GameOverSubState.character = char;
			GameOverSubState.deathSound = lossSfx;
			GameOverSubState.deathMusic = song;
			GameOverSubState.deathConfirm = confirmSound;
			GameOverSubState.deathBPM = bpm;
		});

		set('get', function(variable:String)
		{
			return Reflect.getProperty(this, variable);
		});

		set('setGraphicSize', function(width:Int = 0, height:Int = 0)
		{
			setGraphicSize(width, height);
			updateHitbox();
		});

		set('setTex', function(character:String, library:String = 'assets', folder:String = 'images')
		{
			frames = Paths.getSparrowAtlas(character, library, folder);
		});

		set('setPacker', function(character:String, library:String = 'assets', folder:String = 'images')
		{
			frames = Paths.getPackerAtlas(character, library, folder);
		});

		set('playAnim', function(name:String, ?force:Bool = false, ?reversed:Bool = false, ?frames:Int = 0)
		{
			playAnim(name, force, reversed, frames);
		});

		set('isPlayer', isPlayer);
		set('curStage', PlayState.curStage);

		call('loadAnimations', null);

		if (isPlayer) // fuck you ninjamuffin lmao
		{
			flipX = !!flipX;
		}

		if (icon == null)
			icon = curCharacter;

		if (animation.getByName('danceLeft') != null)
			playAnim('danceLeft');
		else
			playAnim('idle');
	}

	public function call(key:String, value:Dynamic)
	{
		for (i in scriptArray)
		{
			if (i.exists(key))
				i.get(key)(value);
		}

		return key;
	}

	public function set(key:String, value:Dynamic):Bool
	{
		for (i in scriptArray)
			i.set(key, value);

		return true;
	}

	public var psychAnimationsArray:Array<PsychAnimArray> = [];

	function generatePsychChar()
	{
		/**
		 * @author Shadow_Mario_
		 */
		var path = Paths.getPreloadPath('characters/$character/' + character + '.json');

		#if MODS_ALLOWED
		var rawJson = File.getContent(path);
		#else
		var rawJson = Assets.getText(path);
		#end

		var json:PsychEngineChar = cast Json.parse(rawJson);
		var spriteType = "sparrow";

		#if MODS_ALLOWED
		var modTxtToFind:String = Paths.getModPath('characters/$character', json.image, 'txt');
		var txtToFind:String = Paths.getPath('characters/$character/' + json.image + '.txt', TEXT);

		if (FileSystem.exists(modTxtToFind) || FileSystem.exists(txtToFind) || Assets.exists(txtToFind))
		#else
		if (Assets.exists(Paths.getPath('characters/$character/' + json.image + '.txt', TEXT)))
		#end
		{
			spriteType = "packer";
		}
		switch (spriteType)
		{
			case "packer":
				frames = Paths.getPackerAtlas(json.image.replace('characters/', ''), 'assets', 'characters/$character');
			case "sparrow":
				frames = Paths.getSparrowAtlas(json.image.replace('characters/', ''), 'assets', 'characters/$character');
			case "sparrow-hash":
				frames = Paths.getSparrowHashAtlas(json.image.replace('characters/', ''), 'assets', 'characters/$character');
		}

		psychAnimationsArray = json.animations;
		for (anim in psychAnimationsArray)
		{
			var animAnim:String = '' + anim.anim;
			var animName:String = '' + anim.name;
			var animFps:Int = anim.fps;
			var animLoop:Bool = !!anim.loop; // Bruh
			var animIndices:Array<Int> = anim.indices;
			if (animIndices != null && animIndices.length > 0)
				animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
			else
				animation.addByPrefix(animAnim, animName, animFps, animLoop);

			if (anim.offsets != null && anim.offsets.length > 1)
				addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
		}
		flipX = json.flip_x;
		antialiasing = !json.no_antialiasing;

		if (isPlayer) // fuck you ninjamuffin lmao
		{
			flipX = !flipX;
		}

		// icon = json.healthicon;
		barColor = json.healthbar_colors;
		singDuration = json.sing_duration;
		scale.set(json.scale, json.scale);
		updateHitbox();

		if (animation.getByName('danceLeft') != null)
			playAnim('danceLeft');
		else
			playAnim('idle');
	}
}