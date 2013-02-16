/*
    Copyright (C) 2012, 2013 Johan Mattsson

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

using Cairo;
using Xml;

namespace BirdFont {

public enum FontFormat {
	FFI,
	SVG,
	FREETYPE
}

public class Font : GLib.Object {
	
	/** Table with glyphs sorted by their unicode value. */
	GlyphTable glyph_cache = new GlyphTable ();
	
	/** Table with glyphs sorted by their name. */
	GlyphTable glyph_name = new GlyphTable ();

	/** Table with ligatures. */
	GlyphTable ligature = new GlyphTable ();
	
	public List <string> background_images = new List <string> ();
	public string background_scale = "1";
		
	/** Top margin */
	public double top_limit;
		
	/** Height of upper case letters. */
	public double top_position;

	/** x-height upper bearing from origo. */
	public double xheight_position;

	/** Base line coordinate from origo. */
	public double base_line;
	
	/** Descender position */
	public double bottom_position;
	
	/** Bottom margin */
	public double bottom_limit;
	
	public string? font_file = null;
	
	bool modified = false;
	
	private string name = "typeface";
	public bool initialised = true;
	
	bool ttf_export = true;
	bool svg_export = true;

	OpenFontFormatReader otf;
	bool otf_font = false;
	
	public List<string> grid_width = new List<string> ();
	
	/** File format. */
	public FontFormat format = FontFormat.FFI;
	
	public Font () {
		// positions in pixels at first zoom level
		// default x-height should be 60 in 1:1
		top_limit = -66 ;
		top_position = -54;
		xheight_position = -38;
		base_line = 18;
		bottom_position = 38;
		bottom_limit = 45;
	}

	public void touch () {
		modified = true;
	}

	public bool get_ttf_export () {
		return ttf_export;
	}

	public bool get_svg_export () {
		return svg_export;
	}

	public File get_backgrounds_folder () {
		string fn = @"$(get_name ()) backgrounds";
		File f = BirdFont.get_settings_directory ().get_child (fn);
		return f;
	}

	/** Retuns true if the current font has be modified */
	public bool is_modified () {
		return modified;
	}

	/** Full path to this font file. */
	public string get_path () {
		int i = 0;
		
		if (font_file != null) {
			return (!) font_file;
		}
		
		StringBuilder sb = new StringBuilder ();
		sb.append (Environment.get_home_dir ());
		sb.append (@"/$(get_name ()).ffi");
		
		File f = File.new_for_path (sb.str);

		while (f.query_exists ()) {
			sb.erase ();
			sb.append (Environment.get_home_dir ());
			sb.append (@"/$(get_name ())$(++i).ffi");
			f = File.new_for_path (sb.str);
		}
		
		return sb.str;
	}

	public string get_file_name () {
		string p = get_path ();
		int i = p.last_index_of ("/");
		
		if (i == -1) {
			i = p.last_index_of ("\\");
		}
		
		p = p.substring (i + 1);
		
		return p;
	}
		
	public File get_folder () {
		string p = get_path ();
		int i = p.last_index_of ("/");
		
		if (i == -1) {
			i = p.last_index_of ("\\");
		}
		
		p = p.substring (0, i);
		
		return File.new_for_path (p);
	}
	
	public double get_height () {
		double r = base_line - top_position;
		return (r > 0) ? r : -r;
	}
		
	public void set_name (string name) {
		string n = name;
		this.name = n;
	}
	
	public string get_name () {
		return name;
	}

	public void print_all () {
		stdout.printf ("Unicode:\n");		
		glyph_cache.for_each((g) => {
			stdout.printf (@"$(g.get_unicode ())\n");
		});
		
		stdout.printf ("Names:\n");	
		glyph_name.for_each((g) => {
			stdout.printf (@"$(g.get_name ())\n");
		});
	}

	public bool has_glyph (string n) {
		return get_glyph (n) != null;
	}

	public Glyph get_nonmarking_return () {
		Glyph ret;
		
		if (has_glyph ("nonmarkingreturn")) {
			return (!) get_glyph ("nonmarkingreturn");
		}
				
		ret = new Glyph ("nonmarkingreturn", '\r');
		ret.set_unassigned (false);
		ret.left_limit = 0;
		ret.right_limit = 0;
		ret.remove_empty_paths ();
		
		assert (ret.path_list.length () == 0);
		
		return ret;
	}
		
	public Glyph get_null_character () {
		Glyph n;
		
		if (has_glyph ("null")) {
			return (!) get_glyph ("null");
		}
		
		n = new Glyph ("null", '\0');
		n.set_unassigned (false);
		n.left_limit = 0;
		n.right_limit = 0;
		n.remove_empty_paths ();
		
		assert (n.path_list.length () == 0);
		
		return n;
	}
	
	public Glyph get_space () {
		Glyph n;
		
		if (has_glyph (" ")) {
			return (!) get_glyph (" ");
		}

		if (has_glyph ("space")) {
			return (!) get_glyph ("space");
		}
				
		n = new Glyph ("space", ' ');
		n.set_unassigned (false);
		n.left_limit = 0;
		n.right_limit = 27;
		n.remove_empty_paths ();
		
		assert (n.path_list.length () == 0);
		
		return n;		
	}
	
	public Glyph get_not_def_character () {
		Glyph g;

		Path p;
		Path i;
		
		if (has_glyph (".notdef")) {
			return (!) get_glyph (".notdef");
		}
		
		g = new Glyph (".notdef", 0);
		p = new Path ();
		i = new Path ();
		
		g.set_unassigned (true);
		g.left_limit = -33;
		g.right_limit = 33;
		
		p.add (-20, -top_position - 5);
		p.add (20, -top_position - 5);
		p.add (20, -base_line + 5);
		p.add (-20, -base_line + 5);
		p.close ();
		
		i.add (-15, -top_position - 10);
		i.add (15, -top_position - 10);
		i.add (15, -base_line + 10);
		i.add (-15, -base_line + 10);
		i.reverse ();
		i.close ();

		g.add_path (i);
		g.add_path (p);

		return g;
	}
		
	public void add_glyph (Glyph glyph) {
		GlyphCollection? gc = get_glyph_collection (glyph.get_name ());

		if (gc == null) {
			add_glyph_collection (new GlyphCollection (glyph));
		}
	}

	public void add_glyph_collection (GlyphCollection glyph_collection) {
		GlyphCollection? gc;
		
		if (glyph_collection.get_name () == "") {
			warning ("Refusing to insert glyph with name \"\", null character should be named null.");
			return;
		}
		
		gc = glyph_name.get (glyph_collection.get_name ());
		if (gc != null) {
			warning ("glyph has already been added");
			return;
		}
		
		if (glyph_collection.get_unicode () != "") {
			glyph_name.insert (glyph_collection.get_name (), glyph_collection);			
		}
		
		glyph_cache.insert (glyph_collection.get_unicode (), glyph_collection);
	}
	
	public string get_name_for_character (unichar c) {
		// if some glyph is already mapped to unichar, return it's name
		uint i = 0;
		Glyph? gl;
		Glyph g;
		StringBuilder sb;
		
		while ((gl = get_glyph_indice (i++)) != null) {
			g = (!) gl;
			
			if (g.unichar_code == c) {
				return g.name;
			}
		}
						
		// otherwise return some default name, possibly from unicode database
		if (c == 0) {
			return ".null".dup ();
		}
		
		sb = new StringBuilder ();
		sb.append_unichar (c);
		return sb.str;		
	}
	
	public bool has_name (string name) {
		return glyph_name.has_key (name);
	}
	
	public void delete_glyph (GlyphCollection glyph) {
		glyph_cache.remove (glyph.get_unicode ());
		glyph_name.remove (glyph.get_name ());
		ligature.remove (glyph.get_current ().get_ligature_string ());
	}

	// FIXME: order of ligature substitutions is important
	public GlyphCollection? get_ligature (uint indice) {
		return ligature.nth (indice);
	}
	
	/** Obtain all versions and alterntes for this glyph. */
	public GlyphCollection? get_glyph_collection (string glyph) {
		GlyphCollection? gc = get_cached_glyph_collection (glyph);
		Glyph? g;
		
		if (gc == null && otf_font) {
			// load it from otf file if we need to
			g = otf.read_glyph (glyph);
			
			if (g != null) {
				add_glyph_callback ((!) g);
				return get_cached_glyph_collection (glyph);
			}
		}
			
		return gc;
	}

	/** Get glyph collection by unichar code. */
	public GlyphCollection? get_cached_glyph_collection (string unichar_code) {
		GlyphCollection? gc = null;
		gc = glyph_cache.get (unichar_code);
		return gc;
	}

	/** Get glyph collection by name. */
	public GlyphCollection? get_glyph_collection_by_name (string glyph) {
		// TODO: load from disk here if needed.
		GlyphCollection? gc = null;
		gc = glyph_name.get (glyph);		
		return gc;
	}

	/** Get glyph by name. */	
	public Glyph? get_glyph_by_name (string glyph) {
		GlyphCollection? gc = get_glyph_collection_by_name (glyph);
		
		if (gc == null) {
			return null;
		}
		
		return ((!)gc).get_current ();
	}
		
	public Glyph? get_glyph (string unicode) {
		GlyphCollection? gc = null;
		gc = glyph_cache.get (unicode);

		if (gc == null) {
			return null;
		}
		
		return ((!)gc).get_current ();
	}
	
	public Glyph? get_glyph_indice (unichar glyph_indice) {
		GlyphCollection? gc;
		
		if (!(0 <= glyph_indice < glyph_name.length ())) {
			return null;
		}
		
		gc = glyph_name.nth (glyph_indice);
		
		if (gc != null) {
			return ((!) gc).get_current ();
		}
		
		return null;
	}
	
	public void add_background_image (string file) {
		background_images.append (file);
	}

	/** Obtain kerning for pair with name a and b.
	 * @param a name of left glyph kerning pair
	 * @param b name of right glyph kerning pair
	 */
	public double get_kerning_by_name (string a, string b) {
		Glyph? gl = get_glyph_by_name (a);
		Glyph g;
		
		if (gl == null) {
			warning (@"glyph \"$a\" does not exist cannot obtain kerning");
			return 0;
		}
		
		g = (!) gl;
		
		return g.get_kerning (b);
	}

	/** Set kerning for pair with name a and b.
	 * @param a name of left glyph kerning pair
	 * @param b name of right glyph kerning pair
	 * @param val kerning
	 */	
	public void set_kerning_by_name (string a, string b, double val) {
		Glyph? gl;
		Glyph g;
		
		gl = get_glyph_by_name (a);
		
		if (unlikely (gl == null)) {
			warning (@"glyph \"$a\" is not parsed yet cannot add kerning");
			return;
		}
		
		g = (!) gl;
		g.add_kerning (b, val);		
	}

	// TODO: this can be removed
	public double get_kerning (string a, string b) {
		Glyph? gl = get_glyph (a);
		Glyph g;
		
		if (gl == null) {
			warning (@"glyph \"$a\" does not exist cannot obtain kerning");
			return 0;
		}
		
		g = (!) gl;
		
		return g.get_kerning (b);
	}

	// TODO: this can be removed
	public void set_kerning (string a, string b, double val) {
		Glyph? gl;
		Glyph g;
		
		gl = get_glyph (a);
		
		if (unlikely (gl == null)) {
			warning (@"glyph \"$a\" is not parsed yet cannot add kerning");
			return;
		}
		
		g = (!) gl;
		g.add_kerning (b, val);
	}

	/** Delete temporary rescue files. */
	public void delete_backup () {
		File dir = BirdFont.get_backup_directory ();
		File? new_file = null;
		File file;
		string backup_file;
		
		new_file = dir.get_child (@"$(name).ffi");
		backup_file = (!) ((!) new_file).get_path ();
		
		try {
			file = File.new_for_path (backup_file);
			if (file.query_exists ()) {
				file.delete ();	
			}
		} catch (GLib.Error e) {
			stderr.printf (@"Failed to delete backup\n");
			warning (@"$(e.message) \n");
		}
	}
	
	/** Returns path to backup file. */
	public string save_backup () {
		File dir = BirdFont.get_backup_directory ();
		File? temp_file = null;
		string backup_file;

		temp_file = dir.get_child (@"$(name).ffi");
		backup_file = (!) ((!) temp_file).get_path ();
		backup_file = backup_file.replace (" ", "_");
		
		write_font_file (backup_file, true);
		
		return backup_file;
	}
	
	public bool save (string path) {
		Font font;
		bool file_written = write_font_file (path);
		
		if (file_written) {
			font_file = path;
			
			// delete backup when font is saved
			font = BirdFont.get_current_font ();
			font.delete_backup ();
		}
		
		modified = false;
		add_thumbnail ();
		Preferences.add_recent_files (get_path ());
		
		return file_written;
	}

	public bool write_font_file (string path, bool backup = false) {
		try {
			File file = File.new_for_path (path);

			if (file.query_file_type (0) == FileType.DIRECTORY) {
				stderr.printf (@"Can not save font. $path is a directory.");
				return false;
			}
			
			if (file.query_exists ()) {
				file.delete ();
			}
			
			DataOutputStream os = new DataOutputStream(file.create(FileCreateFlags.REPLACE_DESTINATION));
			
			os.put_string ("""<?xml version="1.0" encoding="utf-8" standalone="yes"?>""");
			os.put_string ("\n");
				
			os.put_string ("<font>\n");
			
			// this a backup of another font
			if (backup) {
				if (unlikely (font_file == null)) {
					warning ("No file name is set, write backup file name to font file.");
				} else {
					os.put_string ("\n");
					os.put_string (@"<!-- This is a backup of the following font: -->\n");	
					os.put_string (@"<backup>$((!) font_file)</backup>\n");	
				}
			}
			
			os.put_string ("\n");
			os.put_string (@"<name>$(get_name ())</name>\n");
			
			os.put_string ("\n");
			os.put_string (@"<ttf-export>$(ttf_export)</ttf-export>\n");

			os.put_string ("\n");
			os.put_string (@"<svg-export>$(svg_export)</svg-export>\n");
			
			os.put_string ("\n");
			os.put_string ("<lines>\n");
			
			os.put_string (@"\t<top_limit>$top_limit</top_limit>\n");
			os.put_string (@"\t<top_position>$top_position</top_position>\n");
			os.put_string (@"\t<x-height>$xheight_position</x-height>\n");
			os.put_string (@"\t<base_line>$base_line</base_line>\n");
			os.put_string (@"\t<bottom_position>$bottom_position</bottom_position>\n");
			os.put_string (@"\t<bottom_limit>$bottom_limit</bottom_limit>\n");
			
			os.put_string ("</lines>\n\n");

			foreach (string gv in grid_width) {
				os.put_string (@"<grid width=\"$(gv)\"/>\n");
			}
			
			if (GridTool.sizes.length () > 0) {
				os.put_string ("\n");
			}
			
			os.put_string (@"<background scale=\"$(background_scale)\" />\n");
			os.put_string ("\n");
			
			if (background_images.length () > 0) {
				os.put_string (@"<images>\n");
				
				foreach (string f in background_images) {
					os.put_string (@"\t<img src=\"$f\"/>\n");
				}
			
				os.put_string (@"</images>\n");
				os.put_string ("\n");
			}
			
			glyph_cache.for_each ((gc) => {
				bool selected;
				
				if (is_null (gc)) {
					warning ("No glyph collection");
				}
				
				try {
					foreach (Glyph g in gc.get_version_list ().glyphs) {
						selected = (g == gc.get_current ());
						write_glyph (g, selected, os);
					}
				} catch (GLib.Error ef) {
					stderr.printf (@"Failed to save $path \n");
					stderr.printf (@"$(ef.message) \n");
				}
			});
		
			glyph_cache.for_each ((gc) => {
				Glyph glyph;
				
				try {
					glyph = gc.get_current ();
					
					foreach (Kerning k in glyph.kerning) {
						string l, r;
						Glyph? gr = get_glyph (k.glyph_right);
						Glyph glyph_right;

						if (gr == null) {
							warning ("kerning a glyph that does not exist. (" + glyph.name + " -> " + k.glyph_right + ")");
							continue;
						}
						
						glyph_right = (!) gr;
						
						l = Font.to_hex_code (glyph.unichar_code);
						r = Font.to_hex_code (glyph_right.unichar_code);
										
						os.put_string (@"<hkern left=\"U+$l\" right=\"U+$r\" kerning=\"$(k.val)\"/>\n");
					}
				} catch (GLib.Error e) {
					warning (e.message);
				}
			});

			glyph_cache.for_each ((gc) => {
				GlyphBackgroundImage bg;
				
				try {
					string data;
					
					foreach (Glyph g in gc.get_version_list ().glyphs) {

						if (g.get_background_image () != null) {
							bg = (!) g.get_background_image ();
							data = bg.get_png_base64 ();
							
							if (!bg.is_valid ()) {
								continue;
							}
							
							os.put_string (@"<background-image sha1=\"");
							os.put_string (bg.get_sha1 ());
							os.put_string ("\" ");
							os.put_string (" data=\"");
							os.put_string (data);
							os.put_string ("");
							os.put_string ("\" />\n");	
						}
					}
				} catch (GLib.Error ef) {
					stderr.printf (@"Failed to save $path \n");
					stderr.printf (@"$(ef.message) \n");
				}
			});
						
			os.put_string ("</font>");
			
		} catch (GLib.Error e) {
			stderr.printf (@"Failed to save $path \n");
			stderr.printf (@"$(e.message) \n");
			return false;
		}
		
		return true;
	}

	private void write_glyph (Glyph g, bool selected, DataOutputStream os) throws GLib.Error {
		os.put_string (@"<glyph unicode=\"$(to_hex (g.unichar_code))\" selected=\"$selected\" left=\"$(g.left_limit)\" right=\"$(g.right_limit)\">\n");

		foreach (var p in g.path_list) {
			if (p.points.length () == 0) {
				continue;
			}
			
			os.put_string ("\t<object>");

			foreach (var ep in p.points) {
				os.put_string (@"<point x=\"$(ep.x)\" y=\"$(ep.y)\" ");
				
				if (ep.right_handle.type == PointType.CURVE) {
					os.put_string (@"right_type=\"cubic\" ");
				}

				if (ep.left_handle.type == PointType.CURVE) {
					os.put_string (@"left_type=\"cubic\" ");
				}

				if (ep.right_handle.type == PointType.QUADRATIC) {
					os.put_string (@"right_type=\"quadratic\" ");
				}

				if (ep.left_handle.type == PointType.QUADRATIC) {
					os.put_string (@"left_type=\"quadratic\" ");
				}

				if (ep.right_handle.type == PointType.LINE) {
					os.put_string (@"right_type=\"linear\" ");
				}

				if (ep.left_handle.type == PointType.LINE) {
					os.put_string (@"left_type=\"linear\" ");
				}
								
				if (ep.right_handle.type == PointType.CURVE || ep.right_handle.type == PointType.QUADRATIC) {
					os.put_string (@"right_angle=\"$(ep.right_handle.angle)\" ");
					os.put_string (@"right_length=\"$(ep.right_handle.length)\" ");
				}
				
				if (ep.left_handle.type == PointType.CURVE) {
					os.put_string (@"left_angle=\"$(ep.left_handle.angle)\" ");
					os.put_string (@"left_length=\"$(ep.left_handle.length)\" ");						
				}
				
				if (ep.right_handle.type == PointType.CURVE || ep.left_handle.type == PointType.CURVE) {
					os.put_string (@"tie_handles=\"$(ep.tie_handles)\" ");
				}
				
				os.put_string ("/>");
				
			}
			
			os.put_string ("</object>\n");
		}
		
		GlyphBackgroundImage? bg = g.get_background_image ();
		
		if (bg != null) {
			GlyphBackgroundImage background_image = (!) bg;

			double pos_x = background_image.img_x;
			double pos_y = background_image.img_y;
			
			double scale_x = background_image.img_scale_x;
			double scale_y = background_image.img_scale_y;
			
			double rotation = background_image.img_rotation;
			
			if (background_image.is_valid ()) {
				os.put_string (@"\t<background sha1=\"$(background_image.get_sha1 ())\" x=\"$pos_x\" y=\"$pos_y\" scale_x=\"$scale_x\" scale_y=\"$scale_y\" rotation=\"$rotation\"/>\n");
			}
		}
		
		os.put_string ("</glyph>\n\n"); 

	}

	public void set_font_file (string path) {
		font_file = path;
		modified = false;
	}

	public uint length () {
		return glyph_name.length ();
	}

	public bool is_empty () {
		return (glyph_name.length () == 0);
	}

	public bool load (string path, bool recent = true) {
		bool loaded = false;
		initialised = true;
		
		try {
			otf_font = false;

			while (grid_width.length () > 0) {
				grid_width.remove_link (grid_width.first ());
			}

			glyph_cache.remove_all ();
			glyph_name.remove_all ();
			ligature.remove_all ();
			
			if (path.has_suffix (".svg")) {
				font_file = path;
				loaded = parse_svg_file (path);
				format = FontFormat.SVG;
			}
			
			if (path.has_suffix (".ffi")) {
				font_file = path;
				loaded = parse_file (path);
				format = FontFormat.FFI;
			}
			
			if (path.has_suffix (".ttf") || path.has_suffix (".otf")) {
				font_file = path;
				loaded = parse_freetype_file (path);
				format = FontFormat.FREETYPE;
			}			
			
			/* // TODO: Remove the old way of loading ttfs when testing of the OTF writer is complete.
			if (BirdFont.experimental) {
				if (path.has_suffix (".ttf")) {
					font_file = path;
					loaded = parse_otf_file (path);
				}
			}*/
			
			if (recent) {
				add_thumbnail ();
				Preferences.add_recent_files (get_path ());
			}
		} catch (GLib.Error e) {
			warning (e.message);
			return false;
		}
		
		return loaded;
	}

	private bool parse_freetype_file (string path) {
		string svg;
		StringBuilder? data;
		int error;
		SvgFont svg_loader = new SvgFont (this);
		
		data = load_freetype_font (path, out error);
		
		if (error != 0) {
			warning ("Failed to load font.");
			return false;
		}
		
		if (data == null) {
			warning ("No svg data.");
			return false;
		}
		
		svg = ((!) data).str;
		svg_loader.load_svg_data (svg);

		return true;
	}

	private bool parse_svg_file (string path) {
		print ("parse_svg_file\n");
		SvgFont svg_font = new SvgFont (this);
		svg_font.load (path);
		return true;
	}

	private void add_thumbnail () {
		File f = BirdFont.get_thumbnail_directory ().get_child (@"$((!) get_file_name ()).png");
		Glyph? gl = get_glyph ("a");
		Glyph g;
		ImageSurface img;
		ImageSurface img_scale;
		Context cr;
		double scale;
		
		if (gl == null) {
			gl = get_glyph_indice (4);
		}		
		
		if (gl == null) {
			gl = get_not_def_character ();
		}
		
		g = (!) gl;

		img = g.get_thumbnail ();
		scale = 70.0 / img.get_width ();
		
		if (scale > 70.0 / img.get_height ()) {
			scale = 70.0 / img.get_height ();
		}
		
		if (scale > 1) {
			scale = 1;
		}

		img_scale = new ImageSurface (Format.ARGB32, (int) (scale * img.get_width ()), (int) (scale * img.get_height ()));
		cr = new Context (img_scale);
		
		cr.scale (scale, scale);

		cr.save ();
		cr.set_source_surface (img, 0, 0);
		cr.paint ();
		cr.restore ();
		
		img_scale.write_to_png ((!) f.get_path ());
	}

	/** Callback function for loading glyph in a separate thread. */
	public void add_glyph_callback (Glyph g) {
		GlyphCollection? gcl;
		GlyphCollection gc;
		string liga;
							
		gcl = get_cached_glyph_collection (g.get_name ());
		
		if (gcl != null) {
			warning (@"glyph \"$(g.get_name ())\" does already exist");
		}
				
		if (g.is_unassigned ()) {
			gc = new GlyphCollection (g);
		}

		gc = new GlyphCollection (g);
		add_glyph_collection (gc);

		if (g.is_ligature ()) {
			liga = g.get_ligature_string ();
			ligature.insert (liga, gc);
		}
						
		// take xheight from appropriate lower case letter
		// xheight_position = estimate_xheight ();
	}

	public bool parse_otf_file (string path) throws GLib.Error {
		otf = new OpenFontFormatReader ();
		otf_font = true;
		otf.parse_index (path);
		return true;
	}
	
	public bool parse_file (string path) throws GLib.Error {
		Parser.init ();
		
		Xml.Doc* doc;
		Xml.Node* root;
		Xml.Node* node;

		// set this path as file for this font, it will be updated if this is a backup
		font_file = path;
		
		// empty cache and fill it with new glyphs from disk
		glyph_cache.remove_all ();
		glyph_name.remove_all ();

		while (background_images.length () > 0) {
			background_images.remove_link (background_images.first ());
		}

		create_background_files (path);

		doc = Parser.parse_file (path);
		root = doc->get_root_element ();
		
		if (root == null) {
			delete doc;
			return false;
		}

		node = root;
		
		for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {

			// this is a backup file set path to the original 
			if (iter->name == "backup") {
				font_file = iter->children->content;
			}
	
			if (iter->name == "glyph") {
				parse_glyph (iter);
			}

			if (iter->name == "lines") {
				parse_font_boundries (iter);
			}

			if (iter->name == "grid") {
				parse_grid (iter);
			}

			if (iter->name == "background") {
				parse_background (iter);
			}
			
			if (iter->name == "images") {
				parse_background_selection (iter);
			}

			if (iter->name == "name" && iter->children != null) {
				set_name (iter->children->content);
			}

			if (iter->name == "hkern") {
				parse_kerning (iter);
			}

			if (iter->name == "ttf-export") {
				ttf_export = bool.parse (iter->children->content);
			}			

			if (iter->name == "svg-export") {
				svg_export = bool.parse (iter->children->content);
			}
			
		}
    
		delete doc;
		Parser.cleanup ();

		return true;
	}
	
	private void create_background_files (string path) {
		Xml.Doc* doc = Parser.parse_file (path);
		Xml.Node* root;
		Xml.Node* node;
		
		root = doc->get_root_element ();
		
		if (root == null) {
			delete doc;
			return;
		}

		node = root;
		
		for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
			
			if (iter->name == "name" && iter->children != null) {
				set_name (iter->children->content);
			}
			
			if (iter->name == "background-image") {
				parse_background_image (iter);
			}
		}
    
		delete doc;
		Parser.cleanup ();
	}
	
	private void parse_kerning (Xml.Node* node) {
		string attr_name;
		string attr_content;
		string left = "";
		string right = "";
		string kern = "";

		StringBuilder b;
		
		for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
			attr_name = prop->name;
			attr_content = prop->children->content;
			
			if (attr_name == "left") {
				b = new StringBuilder ();
				b.append_unichar (to_unichar (attr_content));
				left = @"$(b.str)";
			}

			if (attr_name == "right") {
				b = new StringBuilder ();
				b.append_unichar (to_unichar (attr_content));
				right = @"$(b.str)";
			}
			
			if (attr_name == "kerning") {
				kern = attr_content;
			}
		}
		
		set_kerning (left, right, double.parse (kern));
	}
	
	private void parse_background_image (Xml.Node* node) 
		requires (node != null)
	{
		string attr_name;
		string attr_content;
		
		string file = "";
		string data = "";
		
		File img_dir;
		File img_file;
		FileOutputStream file_stream;
		DataOutputStream png_stream;
		
		for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
			return_if_fail (!is_null (prop->name));
			return_if_fail (!is_null (prop->children));
			return_if_fail (!is_null (prop->children->content));
			
			attr_name = prop->name;
			attr_content = prop->children->content;
			
			if (attr_name == "sha1") {
				file = attr_content;
			}
			
			if (attr_name == "data") {
				data = attr_content;
			}
		}
		
		img_dir = get_backgrounds_folder ().get_child ("parts");

		if (!img_dir.query_exists ()) {
			DirUtils.create ((!) img_dir.get_path (), 0xFFFFFF);
		}
	
		img_file = img_dir.get_child (@"$(file).png");
		
		if (img_file.query_exists ()) {
			return;
		}
		
		try {
			file_stream = img_file.create (FileCreateFlags.REPLACE_DESTINATION);
			png_stream = new DataOutputStream (file_stream);

			png_stream.write (Base64.decode (data));
			png_stream.close ();	
		} catch (GLib.Error e) {
			warning (e.message);
		}
	}
	
	private void parse_background (Xml.Node* node) 
		requires (node != null)
	{
		string attr_name;
		string attr_content;
				
		for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
			
			return_if_fail (!is_null (prop->name));
			return_if_fail (!is_null (prop->children));
			return_if_fail (!is_null (prop->children->content));
			
			attr_name = prop->name;
			attr_content = prop->children->content;
			
			if (attr_name == "scale") {
				background_scale = attr_content;
			}
		}
	}
	
	private void parse_background_selection (Xml.Node* node) {
		string attr_name = "";
		string attr_content;
		
		return_if_fail (node != null);
				
		for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
			if (iter->name == "img") {
				for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {
					attr_name = prop->name;
					attr_content = prop->children->content;
					
					if (attr_name == "src") {
						background_images.append (attr_content);
					}
				}
			}
		}
	}
	
	private void parse_grid (Xml.Node* node) {
		for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
			string attr_name = prop->name;
			string attr_content = prop->children->content;
			
			if (attr_name == "width") {
				grid_width.append (attr_content);
			}
		}		
	}
	
	private void parse_font_boundries (Xml.Node* node) {
		for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
			if (iter->name == "top_limit") top_limit = parse_double_from_node (iter);
			if (iter->name == "top_position") top_position = parse_double_from_node (iter);
			if (iter->name == "x-height") xheight_position = parse_double_from_node (iter);
			if (iter->name == "base_line") base_line = parse_double_from_node (iter);
			if (iter->name == "bottom_position") bottom_position = parse_double_from_node (iter);
			if (iter->name == "bottom_limit") bottom_limit = parse_double_from_node (iter);
		}			
	}
	
	private double parse_double_from_node (Xml.Node* iter) {
		double d;
		bool r = double.try_parse (iter->children->content, out d);
		
		if (unlikely (!r)) {
			string? s = iter->content;
			if (s == null) warning (@"Content is null for node $(iter->name)\n");
			else warning (@"Failed to parse double for \"$(iter->content)\"\n");
		}
		
		return (r) ? d : 0;
	}
	
	/** Parse one glyph. */
	public void parse_glyph (Xml.Node* node) {
		string name = "";
		int left = 0;
		int right = 0;
		unichar uni = 0;
		int version = 0;
		bool selected = false;
		Glyph g;
		GlyphCollection? gc;
		
		for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
			string attr_name = prop->name;
			string attr_content = prop->children->content;
			StringBuilder b;
			
			if (attr_name == "unicode") {
				uni = to_unichar (attr_content);
				b = new StringBuilder ();
				b.append_unichar (uni);
				name = b.str;
			}

			if (attr_name == "left") {
				left = int.parse (attr_content);
			}
			
			if (attr_name == "right") {
				right = int.parse (attr_content);
			}
			
			if (attr_name == "version") {
				version = int.parse (attr_content);
			}
			
			if (attr_name == "selected") {
				selected = bool.parse (attr_content);
			}
		}

		g = new Glyph (name, uni);
		
		g.left_limit = left;
		g.right_limit = right;

		parse_content (g, node);
		
		// todo: use disk thread and idle add this:
		
		gc = get_glyph_collection (g.get_name ());
		
		if (g.get_name () == "") {
			warning ("No name set for glyph.");
		}
				
		if (gc == null) {
			gc = new GlyphCollection (g);
			add_glyph_collection ((!) gc);
		} else {
			((!)gc).insert_glyph (g, selected);
		}
	}
	
	/** Parse visual objects and paths */
	private void parse_content (Glyph g, Xml.Node* node) {
		Xml.Node* i;
		return_if_fail (node != null);
		
		for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
			if (iter->name == "object") {
				Path p = new Path ();
				
				for (i = iter->children; i != null; i = i->next) {
					if (i->name == "point") {
						parse_point (p, i);
					}					
				}

				p.close ();
				g.add_path (p);
			}
			
			if (iter->name == "background") {
				parse_background_scale (g, iter);
			}
		}
	}
	
	private void parse_background_scale (Glyph g, Xml.Node* node) {
		GlyphBackgroundImage img;
		GlyphBackgroundImage? new_img = null;
		
		string attr_name = "";
		string attr_content;
		
		File img_file = get_backgrounds_folder ().get_child ("parts");
		
		for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
			attr_name = prop->name;
			attr_content = prop->children->content;
			
			if (attr_name == "sha1") {
				img_file = img_file.get_child (attr_content + ".png");

				if (!img_file.query_exists ()) {
					warning (@"Background file has not been created yet. $((!) img_file.get_path ())");
				}
				
				new_img = new GlyphBackgroundImage ((!) img_file.get_path ());
				g.set_background_image ((!) new_img);
			}
		}
		
		if (unlikely (new_img == null)) {
			warning (@"No source for image found for $attr_name in $(g.name)");
			return;
		}
	
		img = (!) new_img;
	
		for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
			attr_name = prop->name;
			attr_content = prop->children->content;
							
			if (attr_name == "x") {
				img.img_x = double.parse (attr_content);
			}
			
			if (attr_name == "y") {
				img.img_y = double.parse (attr_content);
			}	

			if (attr_name == "scale_x") {
				img.img_scale_x = double.parse (attr_content);
			}

			if (attr_name == "scale_y") {
				img.img_scale_y = double.parse (attr_content);
			}
						
			if (attr_name == "rotation") {
				img.img_rotation = double.parse (attr_content);
			}
		}
		
		img.set_position(img.img_x, img.img_y);	
	}
	
	private void parse_point (Path p, Xml.Node* iter) {
		double x = 0;
		double y = 0;
		
		double angle_right = 0;
		double angle_left = 0;
		
		double length_right = 0;
		double length_left = 0;
		
		PointType type_right = PointType.LINE;
		PointType type_left = PointType.LINE;
		
		bool tie_handles = false;
		
		EditPoint ep;
		
		for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {
			string attr_name = prop->name;
			string attr_content = prop->children->content;
						
			if (attr_name == "x") x = double.parse (attr_content);
			if (attr_name == "y") y = double.parse (attr_content);

			if (attr_name == "right_type" && attr_content == "linear") {
				type_right = PointType.LINE;
			}	

			if (attr_name == "left_type" && attr_content == "linear") {
				type_left = PointType.LINE;
			}	

			if (attr_name == "right_type" && attr_content == "quadratic") {
				type_right = PointType.QUADRATIC;
			}	

			if (attr_name == "left_type" && attr_content == "quadratic") {
				type_left = PointType.QUADRATIC;
			}

			if (attr_name == "right_type" && attr_content == "cubic") {
				type_right = PointType.CURVE;
			}	

			if (attr_name == "left_type" && attr_content == "cubic") {
				type_left = PointType.CURVE;
			}
			
			if (attr_name == "right_angle") angle_right = double.parse (attr_content);
			if (attr_name == "right_length") length_right = double.parse (attr_content);
			if (attr_name == "left_angle") angle_left = double.parse (attr_content);
			if (attr_name == "left_length") length_left = double.parse (attr_content);
			
			if (attr_name == "tie_handles") tie_handles = bool.parse (attr_content);
		}
	
		// backward compabtility
		if (type_right == PointType.LINE && length_right != 0) {
			type_right = PointType.CURVE;
		}

		if (type_left == PointType.LINE && length_left != 0) {
			type_left = PointType.CURVE;
		}
		
		ep = new EditPoint (x, y);
		
		ep.right_handle.angle = angle_right;
		ep.right_handle.length = length_right;
		ep.right_handle.type = type_right;
		
		ep.left_handle.angle = angle_left;
		ep.left_handle.length = length_left;
		ep.left_handle.type = type_left;
		
		ep.tie_handles = tie_handles;
		
		p.add_point (ep);
	}
		
	public static string to_hex (unichar ch) {
		StringBuilder s = new StringBuilder ();
		s.append ("U+");
		s.append (to_hex_code (ch));
		return s.str;
	}

	public static string to_hex_code (unichar ch) {
		StringBuilder s = new StringBuilder ();
		
		uint8 a = (uint8)(ch & 0x00000F);
		uint8 b = (uint8)((ch & 0x0000F0) >> 4 * 1);
		uint8 c = (uint8)((ch & 0x000F00) >> 4 * 2);
		uint8 d = (uint8)((ch & 0x00F000) >> 4 * 3);
		uint8 e = (uint8)((ch & 0x0F0000) >> 4 * 4);
		uint8 f = (uint8)((ch & 0xF00000) >> 4 * 5);
		
		if (e != 0 || f != 0) {
			s.append (oct_to_hex (f));
			s.append (oct_to_hex (e));
		}
		
		if (c != 0 || d != 0) {
			s.append (oct_to_hex (d));
			s.append (oct_to_hex (c));
		}
				
		s.append (oct_to_hex (b));
		s.append (oct_to_hex (a));
		
		return s.str;
	}

	public static unichar to_unichar (string unicode) {
		int index = 2;
		int i = 0;
		unichar c;
		unichar rc = 0;
		bool r;

		if (unlikely (unicode.index_of ("U+") != 0)) {
			warning (@"All unicode values must begin with U+ ($unicode)");
			return '\0';
		}
		
		while (r = unicode.get_next_char (ref index, out c)) {
			rc <<= 4;
			rc += hex_to_oct (c);
			
			return_val_if_fail (++i <= 6, '\0');
		}

		return rc;
	}
	
	private static string oct_to_hex (uint8 o) {
		switch (o) {
			case 10: return "a";
			case 11: return "b";
			case 12: return "c";
			case 13: return "d";
			case 14: return "e";
			case 15: return "f";
		}

		return_val_if_fail (0 <= o <= 9, "-".dup ());
		
		return o.to_string ();
	}

	private static uint8 hex_to_oct (unichar o) {
		StringBuilder s = new StringBuilder ();
		s.append_unichar (o);
	
		switch (o) {
			case 'a': return 10;
			case 'b': return 11;
			case 'c': return 12;
			case 'd': return 13;
			case 'e': return 14;
			case 'f': return 15;
		}
		
		return_val_if_fail ('0' <= o <= '9', 0);
		
		return (uint8) (o - '0');
	}

}

}
