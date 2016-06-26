/*
	Copyright (C) 2012 - 2016 Johan Mattsson

	This library is free software; you can redistribute it and/or modify 
	it under the terms of the GNU Lesser General Public License as 
	published by the Free Software Foundation; either version 3 of the 
	License, or (at your option) any later version.

	This library is distributed in the hope that it will be useful, but 
	WITHOUT ANY WARRANTY; without even the implied warranty of 
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
	Lesser General Public License for more details.
*/

using B;
using Math;
using SvgBird;

namespace BirdFont {

public enum SvgFormat {
	NONE,
	INKSCAPE,
	ILLUSTRATOR
}

public enum SvgType {
	COLOR,
	REGULAR
}

public class SvgParser {
	
	SvgFormat format = SvgFormat.ILLUSTRATOR;
	
	public SvgParser () {
	}
	
	public void set_format (SvgFormat f) {
		format = f;
	}
	
	public static void import (SvgType type) {
		FileChooser fc = new FileChooser ();
		fc.file_selected.connect ((p) => {
			string path;
				
			if (p == null) {
				return;
			}
			
			path = (!) p;
			
			if (type == SvgType.REGULAR) {
				import_svg (path);
			} else if (type == SvgType.COLOR) {
				Glyph glyph = MainWindow.get_current_glyph ();
				import_color_svg (glyph, path);
			}
		});
		
		fc.add_extension ("svg");
		MainWindow.file_chooser (t_("Import"), fc, FileChooser.LOAD);
	}
	
	public static void import_svg_color_data (string svg_data) {
		Glyph glyph = MainWindow.get_current_glyph ();
		EmbeddedSvg drawing = SvgParser.parse_embedded_svg_data (svg_data);
		glyph.add_object (drawing);

		Font font = BirdFont.get_current_font ();
		
		drawing.x = glyph.left_limit;
		drawing.y = font.top_position - font.base_line;
		
		drawing.update_boundaries_for_object ();
		
		glyph.clear_active_paths ();
		glyph.add_active_object (drawing);
	}
	
	public static void import_color_svg (Glyph glyph, string path) {
		EmbeddedSvg drawing = SvgParser.parse_embedded_svg_data (path);
		
		glyph.add_object (drawing);
		drawing.update_boundaries_for_object ();
		
		Font font = BirdFont.get_current_font ();
		
		drawing.x = glyph.left_limit;
		drawing.y = font.top_position - font.base_line;
	}
	
	public static void import_folder (SvgType type) {
		FileChooser fc = new FileChooser ();
		fc.file_selected.connect ((p) => {
			string path;
			File svg_folder;
			File svg;
			bool imported;
			FileEnumerator enumerator;
			FileInfo? file_info;
			string file_name;
			Font font;
			
			if (p == null) {
				return;
			}
			
			path = (!) p;
			svg_folder = File.new_for_path (path);
			font = BirdFont.get_current_font ();
				
			try {
				enumerator = svg_folder.enumerate_children (FileAttribute.STANDARD_NAME, 0);
				while ((file_info = enumerator.next_file ()) != null) {
					file_name = ((!) file_info).get_name ();
					
					if (file_name.has_suffix (".svg")) {
						svg = get_child (svg_folder, file_name);
						imported = import_svg_file (font, svg, type);
						
						if (!imported) {
							warning ("Can't import %s.", (!) svg.get_path ());
						} else {
							font.touch ();
						}
					}
				}
			} catch (Error e) {
				warning (e.message);
			}
		});
		
		MainWindow.file_chooser (t_("Import"), fc, FileChooser.LOAD | FileChooser.DIRECTORY);
	}
	
	public static PathList import_svg_data (string xml_data, SvgFormat format = SvgFormat.NONE) {
		Glyph glyph = MainWindow.get_current_glyph ();
		return import_svg_data_in_glyph (xml_data, glyph, format);
	}
	
	public static PathList import_svg_data_in_glyph (string xml_data, Glyph glyph, SvgFormat format = SvgFormat.NONE) {
		PathList path_list = new PathList ();
		string[] lines = xml_data.split ("\n");
		bool has_format = false;
		SvgParser parser = new SvgParser ();

		foreach (string l in lines) {
			if (l.index_of ("Illustrator") > -1 || l.index_of ("illustrator") > -1) {
				parser.set_format (SvgFormat.ILLUSTRATOR);
				has_format = true;
			}
			
			if (l.index_of ("Inkscape") > -1 || l.index_of ("inkscape") > -1) {
				parser.set_format (SvgFormat.INKSCAPE);
				has_format = true;
			}
		}
		
		if (format != SvgFormat.NONE) {
			parser.set_format (format);
		}

		// parse the file
		if (!has_format) {
			warn_if_test ("No format identifier found in SVG parser.\n");
		}

		XmlTree xml_tree = new XmlTree (xml_data);
		path_list = parser.parse_svg_file (xml_tree.get_root ());
	
		foreach (Path p in path_list.paths) {
			PathObject path = new PathObject.for_path (p);
			glyph.add_object (path);
			glyph.add_active_object (path); // FIXME: groups
			path.update_boundaries_for_object ();
		}
		
		glyph.close_path ();
		
		return path_list;
	}
	
	public static string replace (string content, string start, string stop, string replacement) {
		int i_tag = content.index_of (start);
		int end_tag = content.index_of (stop, i_tag);
		string c = "";
		
		if (i_tag > -1) {
			c = content.substring (0, i_tag) 
				+ replacement
				+ content.substring (end_tag + stop.length);
		} else {
			c = content;
		}
		
		return c;
	}
	
	public static void import_svg (string path) {
		string svg_data;
		try {
			FileUtils.get_contents (path, out svg_data);
		} catch (GLib.Error e) {
			warning (e.message);
		}
		import_svg_data (svg_data);
	}
	
	private PathList parse_svg_file (XmlElement tag) {
		Layer pl = new Layer ();
	
		foreach (XmlElement t in tag) {
			
			if (t.get_name () == "g") {
				parse_layer (t, pl);
			}

			if (t.get_name () == "svg") {
				parse_layer (t, pl);
			}
			
			if (t.get_name () == "switch") {
				parse_layer (t, pl);
			}
						
			if (t.get_name () == "path") {
				parse_path (t, pl);
			}
			
			if (t.get_name () == "polygon") {
				parse_polygon (t, pl);
			}

			if (t.get_name () == "polyline") {
				parse_polyline (t, pl);
			}
						
			if (t.get_name () == "circle") {
				parse_circle (t, pl);
			}
			
			if (t.get_name () == "ellipse") {
				parse_ellipse (t, pl);
			}

			if (t.get_name () == "line") {
				parse_line (t, pl);
			}

			if (t.get_name () == "rect") {
				parse_rect (t, pl);
			}
		}
		
		return LayerUtils.get_all_paths (pl);
	}
	
	private void parse_layer (XmlElement tag, Layer pl) {
		Layer layer;
		bool hidden = false;

		foreach (Attribute attr in tag.get_attributes ()) {	
			if (attr.get_name () == "display" && attr.get_content () == "none") {
				hidden = true;
			}
			
			if (attr.get_name () == "visibility"
				&& (attr.get_content () == "hidden" 
					|| attr.get_content () == "collapse")) {
				hidden = true;
			}
		}
		
		if (hidden) {
			return;
		}
					
		foreach (XmlElement t in tag) {
			if (t.get_name () == "path") {
				parse_path (t, pl);
			}
			
			if (t.get_name () == "g") {
				layer = new Layer ();
				parse_layer (t, layer);
				pl.objects.add (layer);
			}

			if (t.get_name () == "svg") {
				layer = new Layer ();
				parse_layer (t, layer);
				pl.objects.add (layer);
			}
				
			if (t.get_name () == "polygon") {
				parse_polygon (t, pl);
			}

			if (t.get_name () == "polyline") {
				parse_polyline (t, pl);
			}
			
			if (t.get_name () == "rect") {
				parse_rect (t, pl);
			}

			if (t.get_name () == "circle") {
				parse_circle (t, pl);
			}

			if (t.get_name () == "ellipse") {
				parse_ellipse (t, pl);
			}
			
			if (t.get_name () == "line") {
				parse_line (t, pl);
			}
		}

		foreach (Attribute attr in tag.get_attributes ()) {	
			if (attr.get_name () == "transform") {
				transform (attr.get_content (), pl);
			}
		}
	}
	
	private void transform (string transform_functions, Layer layer) {
		PathList path_list = new PathList ();
		
		foreach (SvgBird.Object o in layer.objects) {
			if (o is PathObject) {
				path_list.add (((PathObject) o).get_path ());
			}
		}
		
		transform_paths (transform_functions, path_list);
		transform_subgroups (transform_functions, layer);
	}
	
	private void transform_subgroups (string transform_functions, Layer layer) {
		foreach (Layer subgroup in layer.get_sublayers ()) {
			transform (transform_functions, subgroup);
		}
	}
	
	private void transform_paths (string transform_functions, PathList pl) {
		string data = transform_functions.dup ();
		string[] functions;
				
		// use only a single space as separator
		while (data.index_of ("  ") > -1) {
			data = data.replace ("  ", " ");
		}
		
		return_if_fail (data.index_of (")") > -1);
		
		 // add separator
		data = data.replace (") ", "|");
		data = data.replace (")", "|"); 
		functions = data.split ("|");
		
		for (int i = functions.length - 1; i >= 0; i--) {
			if (functions[i].has_prefix ("translate")) {
				translate (functions[i], pl);
			}
			
			if (functions[i].has_prefix ("scale")) {
				scale (functions[i], pl);
			}

			if (functions[i].has_prefix ("matrix")) {
				matrix (functions[i], pl);
			}
			
			// TODO: rotate etc.
		}
	}

	/** @param path a path in the cartesian coordinate system
	 * The other parameters are in the SVG coordinate system.
	 */
	public static void apply_matrix (Path path, double a, double b, double c, 
		double d, double e, double f){
		
		double dx, dy;
		Font font = BirdFont.get_current_font ();
		Glyph glyph = MainWindow.get_current_glyph ();
		
		foreach (EditPoint ep in path.points) {
			ep.tie_handles = false;
			ep.reflective_point = false;
		}
		
		foreach (EditPoint ep in path.points) {
			apply_matrix_on_handle (ep.get_right_handle (), a, b, c, d, e, f);
			apply_matrix_on_handle (ep.get_left_handle (), a, b, c, d, e, f);

			ep.independent_y = font.top_position - ep.independent_y;
			ep.independent_x -= glyph.left_limit;
			
			dx = a * ep.independent_x + c * ep.independent_y + e;
			dy = b * ep.independent_x + d * ep.independent_y + f;
			
			ep.independent_x = dx;
			ep.independent_y = dy;
			
			ep.independent_y = font.top_position - ep.independent_y;
			ep.independent_x += glyph.left_limit;
		}
	}

	public static void apply_matrix_on_handle (EditPointHandle h, 
		double a, double b, double c, 
		double d, double e, double f){
		
		double dx, dy;
		Font font = BirdFont.get_current_font ();
		Glyph glyph = MainWindow.get_current_glyph ();

		h.y = font.top_position - h.y;
		h.x -= glyph.left_limit;
		
		dx = a * h.x + c * h.y + e;
		dy = b * h.x + d * h.y + f;
		
		h.x = dx;
		h.y = dy;
		
		h.y = font.top_position - h.y;
		h.x += glyph.left_limit;
	}


	private void matrix (string function, PathList pl) {
		string parameters = get_transform_parameters (function);
		string[] p = parameters.split (" ");

		if (p.length != 6) {
			warning ("Expecting six parameters for matrix transformation.");
			return;
		}

		foreach (Path path in pl.paths) {
			apply_matrix (path, parse_double (p[0]), parse_double (p[1]), 
				parse_double (p[2]), parse_double (p[3]), 
				parse_double (p[4]), parse_double (p[5]));
		}
	}
		
	private void scale (string function, PathList pl) {
		string parameters = get_transform_parameters (function);
		string[] p = parameters.split (" ");
		double x, y;
		
		x = 1;
		y = 1;
		
		if (p.length > 0) {
			x = parse_double (p[0]);
		}
		
		if (p.length > 1) {
			y = parse_double (p[1]);
		}
		
		foreach (Path path in pl.paths) {
			path.scale (-x, y);
		}
	}
	
	private void translate (string function, PathList pl) {
		string parameters = get_transform_parameters (function);
		string[] p = parameters.split (" ");
		double x, y;
		
		x = 0;
		y = 0;
		
		if (p.length > 0) {
			x = parse_double (p[0]);
		}
		
		if (p.length > 1) {
			y = parse_double (p[1]);
		}
		
		foreach (Path path in pl.paths) {
			path.move (x, -y);
		}
	}

	private string get_transform_parameters (string function) {
		int i;
		string param = "";
		
		i = function.index_of ("(");
		return_val_if_fail (i != -1, param);
		param = function.substring (i);

		param = param.replace ("(", "");
		param = param.replace ("\n", " ");
		param = param.replace ("\t", " ");
		param = param.replace (",", " ");
		
		while (param.index_of ("  ") > -1) {
			param = param.replace ("  ", " ");
		}
			
		return param.strip();			
	}
	
	private void parse_circle (XmlElement tag, Layer pl) {
		Path p;
		double x, y, r;
		Glyph g;
		PathList npl;
		BezierPoints[] bezier_points;
		SvgStyle style = new SvgStyle ();
		bool hidden = false;
		
		npl = new PathList ();
		
		x = 0;
		y = 0;
		r = 0;
			
		foreach (Attribute attr in tag.get_attributes ()) {			
			if (attr.get_name () == "cx") {
				x = parse_double (attr.get_content ());
			}
			
			if (attr.get_name () == "cy") {
				y = -parse_double (attr.get_content ());
			}

			if (attr.get_name () == "r") {
				r = parse_double (attr.get_content ());
			}
	
			if (attr.get_name () == "display" && attr.get_content () == "none") {
				hidden = true;
			}
		}
		
		style = SvgStyle.parse (null, style, tag);
		
		if (hidden) {
			return;
		}
		
		bezier_points = new BezierPoints[1];
		bezier_points[0] = new BezierPoints ();
		bezier_points[0].type == 'L';
		bezier_points[0].x0 = x;
		bezier_points[0].y0 = y;

		g = MainWindow.get_current_glyph ();
		move_and_resize (bezier_points, 1, false, 1, g);
			
		p = CircleTool.create_circle (bezier_points[0].x0,
			bezier_points[0].y0, r, PointType.CUBIC);

		npl.add (p);
		
		foreach (Attribute attr in tag.get_attributes ()) {
			if (attr.get_name () == "transform") {
				transform_paths (attr.get_content (), npl);
			}
		}
		
		npl.apply_style (style);
		append_paths (pl, npl);
	}

	private void parse_ellipse (XmlElement tag, Layer pl) {
		Path p;
		double x, y, rx, ry;
		Glyph g;
		PathList npl;
		BezierPoints[] bezier_points;
		SvgStyle style = new SvgStyle ();
		bool hidden = false;
		
		npl = new PathList ();
		
		x = 0;
		y = 0;
		rx = 0;
		ry = 0;
		
		foreach (Attribute attr in tag.get_attributes ()) {			
			if (attr.get_name () == "cx") {
				x = parse_double (attr.get_content ());
			}
			
			if (attr.get_name () == "cy") {
				y = -parse_double (attr.get_content ());
			}

			if (attr.get_name () == "rx") {
				rx = parse_double (attr.get_content ());
			}

			if (attr.get_name () == "ry") {
				ry = parse_double (attr.get_content ());
			}
	
			if (attr.get_name () == "display" && attr.get_content () == "none") {
				hidden = true;
			}
		}
		
		style = SvgStyle.parse (null, style, tag);
		
		if (hidden) {
			return;
		}
		
		bezier_points = new BezierPoints[1];
		bezier_points[0] = new BezierPoints ();
		bezier_points[0].type == 'L';
		bezier_points[0].x0 = x;
		bezier_points[0].y0 = y;

		g = MainWindow.get_current_glyph ();
		move_and_resize (bezier_points, 1, false, 1, g);
			
		p = CircleTool.create_ellipse (bezier_points[0].x0,
			bezier_points[0].y0, rx, ry, PointType.CUBIC);

		npl.add (p);
		
		foreach (Attribute attr in tag.get_attributes ()) {
			if (attr.get_name () == "transform") {
				transform_paths (attr.get_content (), npl);
			}
		}
		
		npl.apply_style (style);
		append_paths (pl, npl);
	}

	private void parse_line (XmlElement tag, Layer pl) {
		Path p;
		double x1, y1, x2, y2;
		BezierPoints[] bezier_points;
		Glyph g;
		PathList npl = new PathList ();
		SvgStyle style = new SvgStyle ();
		bool hidden = false;
		
		x1 = 0;
		y1 = 0;
		x2 = 0;
		y2 = 0;
			
		foreach (Attribute attr in tag.get_attributes ()) {			
			if (attr.get_name () == "x1") {
				x1 = parse_double (attr.get_content ());
			}
			
			if (attr.get_name () == "y1") {
				y1 = -parse_double (attr.get_content ());
			}

			if (attr.get_name () == "x2") {
				x2 = parse_double (attr.get_content ());
			}
			
			if (attr.get_name () == "xy") {
				y2 = -parse_double (attr.get_content ());
			}
	
			if (attr.get_name () == "display" && attr.get_content () == "none") {
				hidden = true;
			}
		}
		
		style = SvgStyle.parse (null, style, tag);
		
		if (hidden) {
			return;
		}

		bezier_points = new BezierPoints[2];
		bezier_points[0] = new BezierPoints ();
		bezier_points[0].type == 'L';
		bezier_points[0].x0 = x1;
		bezier_points[0].y0 = y1;

		bezier_points[1] = new BezierPoints ();
		bezier_points[1].type == 'L';
		bezier_points[1].x0 = x2;
		bezier_points[1].y0 = y2;
		
		g = MainWindow.get_current_glyph ();
		move_and_resize (bezier_points, 2, false, 1, g);
					
		p = new Path ();	
		
		p.add (bezier_points[0].x0, bezier_points[0].y0);
		p.add (bezier_points[1].x0, bezier_points[1].y0);
						
		p.close ();
		p.create_list ();
		p.recalculate_linear_handles ();		
		
		npl.add (p);
		
		foreach (Attribute attr in tag.get_attributes ()) {
			if (attr.get_name () == "transform") {
				transform_paths (attr.get_content (), npl);
			}
		}
		
		npl.apply_style (style);
		append_paths (pl, npl);
	}
		
	private void parse_rect (XmlElement tag, Layer layer) {
		Path p;
		double x, y, x2, y2;
		BezierPoints[] bezier_points;
		Glyph g;
		PathList npl = new PathList ();
		SvgStyle style = new SvgStyle ();
		bool hidden = false;
		EditPoint ep;
		
		x = 0;
		y = 0;
		x2 = 0;
		y2 = 0;
			
		foreach (Attribute attr in tag.get_attributes ()) {			
			if (attr.get_name () == "x") {
				x = parse_double (attr.get_content ());
			}
			
			if (attr.get_name () == "y") {
				y = -parse_double (attr.get_content ());
			}

			if (attr.get_name () == "width") {
				x2 = parse_double (attr.get_content ());
			}
			
			if (attr.get_name () == "height") {
				y2 = -parse_double (attr.get_content ());
			}
	
			if (attr.get_name () == "display" && attr.get_content () == "none") {
				hidden = true;
			}
		}
		
		style = SvgStyle.parse (null, style, tag);
		
		if (hidden) {
			return;
		}
		
		x2 += x;
		y2 += y;

		bezier_points = new BezierPoints[4];
		bezier_points[0] = new BezierPoints ();
		bezier_points[0].type == 'L';
		bezier_points[0].x0 = x;
		bezier_points[0].y0 = y;

		bezier_points[1] = new BezierPoints ();
		bezier_points[1].type == 'L';
		bezier_points[1].x0 = x2;
		bezier_points[1].y0 = y;

		bezier_points[2] = new BezierPoints ();
		bezier_points[2].type == 'L';
		bezier_points[2].x0 = x2;
		bezier_points[2].y0 = y2;

		bezier_points[3] = new BezierPoints ();
		bezier_points[3].type == 'L';
		bezier_points[3].x0 = x;
		bezier_points[3].y0 = y2;
		
		g = MainWindow.get_current_glyph ();
		move_and_resize (bezier_points, 4, false, 1, g);
					
		p = new Path ();	
		
		ep = p.add (bezier_points[0].x0, bezier_points[0].y0);
		ep.set_point_type (PointType.CUBIC);
		
		ep = p.add (bezier_points[1].x0, bezier_points[1].y0);
		ep.set_point_type (PointType.CUBIC);
		
		ep = p.add (bezier_points[2].x0, bezier_points[2].y0);
		ep.set_point_type (PointType.CUBIC);
		
		ep = p.add (bezier_points[3].x0, bezier_points[3].y0);
		ep.set_point_type (PointType.CUBIC);
						
		p.close ();
		p.create_list ();
		p.recalculate_linear_handles ();		
		
		npl.add (p);
		
		// FIXME: right layer for other transforms
		foreach (Attribute attr in tag.get_attributes ()) {
			if (attr.get_name () == "transform") {
				transform_paths (attr.get_content (), npl);
			}
		}
		
		npl.apply_style (style);
		append_paths (layer, npl);		
	}
	
	private void parse_polygon (XmlElement tag, Layer layer) {
		PathList path_list = get_polyline (tag);
		
		foreach (Path p in path_list.paths) {
			p.close ();
		}
		
		append_paths (layer, path_list);
	}

	static void append_paths (Layer layer, PathList pl) {
		LayerUtils.append_paths (layer, pl);
	}
	
	private void parse_polyline (XmlElement tag, Layer layer) {	
		append_paths (layer, get_polyline (tag));
	}
	
	private PathList get_polyline (XmlElement tag) {
		Path p = new Path ();
		bool hidden = false;
		PathList path_list = new PathList ();
		SvgStyle style = new SvgStyle ();
				
		foreach (Attribute attr in tag.get_attributes ()) {
			if (attr.get_name () == "points") {
				p = parse_poly_data (attr.get_content ());
			}
	
			if (attr.get_name () == "display" && attr.get_content () == "none") {
				hidden = true;
			}
		}

		style = SvgStyle.parse (null, style, tag);
		
		if (hidden) {
			return path_list;
		}
		
		path_list.add (p);
		path_list.apply_style (style);
		
		foreach (Attribute attr in tag.get_attributes ()) {
			if (attr.get_name () == "transform") {
				transform_paths (attr.get_content (), path_list);
			}
		}
		
		return path_list;
	}
	
	private void parse_path (XmlElement tag, Layer layer) {
		Glyph glyph = MainWindow.get_current_glyph ();
		PathList path_list = new PathList ();
		SvgStyle style = new SvgStyle ();
		bool hidden = false;

		foreach (Attribute attr in tag.get_attributes ()) {
			if (attr.get_name () == "d") {
				path_list = parse_svg_data (attr.get_content (), glyph);
			}
	
			if (attr.get_name () == "display" && attr.get_content () == "none") {
				hidden = true;
			}
			
			if (attr.get_name () == "visibility"
				&& (attr.get_content () == "hidden" 
					|| attr.get_content () == "collapse")) {
				hidden = true;
			}
		}
		
		style = SvgStyle.parse (null, style, tag);
		
		if (hidden) {
			return;
		}
		
		foreach (Path path in path_list.paths) {
			LayerUtils.add_path (layer, path);
		}
		
		path_list.apply_style (style);

		// assume the even odd rule is applied and convert the path
		// to a path using the non-zero rule
		int inside_count;
		bool inside;
		foreach (SvgBird.Object o1 in layer.objects) {
			if (o1 is PathObject) {
				Path p1 = ((PathObject) o1).get_path ();
				inside_count = 0;
				
				foreach (SvgBird.Object o2 in layer.objects) {
					if (o2 is PathObject) {
						Path p2 = ((PathObject) o2).get_path ();
					
						if (p1 != p2) {
							inside = true;
							
							foreach (EditPoint ep in p1.points) {
								if (!is_inside (ep, p2)) {
									inside = false;
								}
							}

							if (inside) {
								inside_count++; 
							}
						}
					}
				}
				
				if (inside_count % 2 == 0) {
					p1.force_direction (Direction.CLOCKWISE);
				} else {
					p1.force_direction (Direction.COUNTER_CLOCKWISE);
				}
			}
		}
		
		foreach (Attribute attr in tag.get_attributes ()) {
			if (attr.get_name () == "transform") {
				transform_paths (attr.get_content (), path_list);
			}
		}
	}

	public static void create_lines_for_segment (Path path, EditPoint start, EditPoint end, double tolerance) {
		double x1, x2, x3;
		double y1, y2, y3;
		double step_start, step, step_end;

		path.add (start.x, start.y);

		step_start = 0;
		step = 0.5;
		step_end = 1;
					
		while (true) {
			Path.get_point_for_step (start, end, step_start, out x1, out y1);
			Path.get_point_for_step (start, end, step, out x2, out y2);
			Path.get_point_for_step (start, end, step_end, out x3, out y3);
		
			if (!StrokeTool.is_flat (x1, y1, x2, y2, x3, y3, tolerance)
				&& step_end - step / 2.0 > step_start 
				&& step_end - step / 2.0 > 0.1
				&& step > 0.05
				&& Path.distance_to_point (start, end) > 1) {
				
				step /= 2.0;
	
				if (step < 0.05) {
					step = 0.05;
				} else {
					step_end = step_start + 2 * step;
				}
			} else {
				path.add (x3, y3);
				
				if (step_end + step < 1) {
					step_start = step_end;
					step_end += step;
				} else {
					break;
				}
			}
		}
	}

	public static Path get_lines (Path p) {
		EditPoint start;
		Path path = new Path ();
		
		if (p.points.size == 0) {
			return path;
		}
		
		// create a set of straight lines
		start = p.points.get (p.points.size - 1);
		
		foreach (EditPoint end in p.points) {
			create_lines_for_segment (path, start, end, 1);
			start = end;
		}
						
		return path;
	}

	/** Check if a point is inside using the even odd fill rule.
	 * The path should only have straight lines.
	 */
	public static bool is_inside (EditPoint point, Path path) {
		EditPoint prev;
		bool inside = false;
		
		if (path.points.size <= 1) {
			return false;
		}

		if (!(path.xmin <= point.x <= path.xmax)) {
			return false;
		}
		
		if (!(path.ymin <= point.y <= path.ymax)) {
			return false;
		}
				
		prev = path.points.get (path.points.size - 1);
		
		foreach (EditPoint p in path.points) {
			if  ((p.y > point.y) != (prev.y > point.y) 
				&& point.x < (prev.x - p.x) * (point.y - p.y) / (prev.y - p.y) + p.x) {
				inside = !inside;
			}
			
			prev = p;
		}
		
		return inside;
	}
	
	public void add_path_to_glyph (string d, Glyph g, bool svg_glyph = false, double units = 1) {
		PathList p = parse_svg_data (d, g, svg_glyph, units);
		foreach (Path path in p.paths) {
			g.add_path (path);
		}
	}
	
	public void get_bezier_points (string svg_data, out BezierPoints[] instructions, out int points, bool svg_glyph) {
		SvgFile.get_bezier_points (svg_data, out instructions, out points, svg_glyph);
		Gee.ArrayList<BezierPoints> bezier_points = new Gee.ArrayList<BezierPoints> ();
		BezierPoints[] arc_data = new BezierPoints[8];
		
		for (int i = 0; i < points; i++) {
			if (instructions[i].type == 'A') {
				int arc_index = 0;
				
				add_arc_points (arc_data, ref arc_index, 
					instructions[i].x0, instructions[i].y0,
					instructions[i].rx, instructions[i].ry,
					instructions[i].angle,
					instructions[i].large_arc,
					instructions[i].sweep,
					instructions[i].x1, instructions[i].y1);
					
				for (int j = 0; j < arc_index; j++) {
					bezier_points.add (instructions[j]);
				}
			}
			
			bezier_points.add (instructions[i]);
		}
	
		instructions = new BezierPoints[bezier_points.size];
		for (int i = 0; i < bezier_points.size; i++) {
			instructions[i] = bezier_points.get (i);
		}
	}
	/** 
	 * @param d svg data
	 * @param glyph use lines from this glyph but don't add the generated paths
	 * @param svg_glyph parse svg glyph with origo in lower left corner
	 * 
	 * @return the new paths
	 */
	public PathList parse_svg_data (string d, Glyph glyph, bool svg_glyph = false, double units = 1) {
		Font font;
		PathList path_list = new PathList ();
		BezierPoints[] bezier_points;
		int points;

		font = BirdFont.get_current_font ();
		SvgFile.get_bezier_points (d, out bezier_points, out points, svg_glyph);
	
		if (points == 0) {
			warning ("No points in path.");
			return path_list;	
		}
		
		move_and_resize (bezier_points, points, svg_glyph, units, glyph);
		
		if (format == SvgFormat.ILLUSTRATOR) {
			path_list = create_paths_illustrator (bezier_points, points);
		} else {
			path_list = create_paths_inkscape (bezier_points, points);
		}

		// TODO: Find out if it is possible to tie handles.
		return path_list;
	}

	void move_and_resize (BezierPoints[] b, int num_b, bool svg_glyph, double units, Glyph glyph) {
		Font font = BirdFont.get_current_font ();
		
		for (int i = 0; i < num_b; i++) {
			// resize all points
			b[i].x0 *= units;
			b[i].y0 *= units;
			b[i].x1 *= units;
			b[i].y1 *= units;
			b[i].x2 *= units;
			b[i].y2 *= units;

			// move all points
			if (svg_glyph) {
				b[i].x0 += glyph.left_limit;
				b[i].y0 += font.base_line;
				b[i].x1 += glyph.left_limit;
				b[i].y1 += font.base_line;
				b[i].x2 += glyph.left_limit;
				b[i].y2 += font.base_line;
			} else {
				b[i].x0 += glyph.left_limit;
				b[i].y0 += font.top_position;
				b[i].x1 += glyph.left_limit;
				b[i].y1 += font.top_position;
				b[i].x2 += glyph.left_limit;
				b[i].y2 += font.top_position;
			}
		}
	}
	
	void find_last_handle (int start_index, BezierPoints[] b, int num_b, out double left_x, out double left_y, out PointType last_type) {
		BezierPoints last = new BezierPoints ();
		bool found = false;
		
		left_x = 0;
		left_y = 0;
		last_type = PointType.NONE;
		
		return_if_fail (b.length != 0);
		return_if_fail (b[0].type != 'z');
		return_if_fail (num_b < b.length);

		if (num_b == 2) {
			left_x = b[0].x0 + (b[1].x0 - b[0].x0) / 3.0;
			left_y = b[0].y0 + (b[1].y0 - b[0].y0) / 3.0;
			last_type = PointType.LINE_CUBIC;
			return;
		}
		
		for (int i = start_index; i < num_b; i++) {
			switch (b[i].type) {
				case 'Q':
					break;
				case 'C':
					break;
				case 'z':
					found = true;
					break;
				default:
					break;
			}
			
			if (found || i + 1 == num_b) {
				
				return_if_fail (i >= 1);
				
				if (b[i - 1].type == 'Q') {
					return_if_fail (i >= 1);
					left_x = b[i - 1].x0;
					left_y = b[i - 1].y0;
					last_type = PointType.QUADRATIC;
				} else if (b[i - 1].type == 'C') {
					return_if_fail (i >= 1);
					left_x = b[i - 1].x1;
					left_y = b[i - 1].y1;
					last_type = PointType.CUBIC;
				} else if (b[i - 1].type == 'S') {
					return_if_fail (i >= 1);
					left_x = b[i - 1].x1;
					left_y = b[i - 1].y1;
					last_type = PointType.CUBIC;
				} else if (b[i - 1].type == 'L' || last.type == 'M') {
					return_if_fail (i >= 2); // FIXME: -2 can be C or L
					left_x = b[i - 2].x0 + (b[i - 1].x0 - b[i - 2].x0) / 3.0;
					left_y = b[i - 2].y0 + (b[i - 1].y0 - b[i - 2].y0) / 3.0;
					last_type = PointType.LINE_CUBIC;
				} else {
					warning (@"Unexpected type. $(b[i - 1])\n");
				}
				return;	
			}
			
			last = b[i];
		}
		
		warning ("Last point not found.");
	}

	PathList create_paths_inkscape (BezierPoints[] b, int num_b) {
		double last_x;
		double last_y; 
		PointType last_type;
		Path path;
		PathList path_list = new PathList ();
		EditPoint ep = new EditPoint ();
		Gee.ArrayList<EditPoint> smooth_points = new Gee.ArrayList<EditPoint> ();
				
		path = new Path ();
		
		if (num_b == 0) {
			warning ("No SVG data");
			return path_list;
		}

		if (b[0].type != 'M') {
			warning ("Path must begin with M or m.");
			return path_list;
		}
		
		find_last_handle (0, b, num_b, out last_x, out last_y, out last_type);

		for (int i = 0; i < num_b; i++) {
			if (b[i].type == '\0') {
				warning ("Parser error.");
				return path_list;
			}

			if (b[i].type == 'z') {
				path.close ();
				path.create_list ();
				path.recalculate_linear_handles ();
				path_list.add (path);
				path = new Path ();
				
				if (i + 1 >= num_b) {
					break;
				} else {
					find_last_handle (i + 1, b, num_b, out last_x, out last_y, out last_type);
				}
			}
			
			if (i >= num_b) {
				break;
			}
			
			if (b[i].type == 'M') {
				ep = path.add (b[i].x0, b[i].y0);
				ep.set_point_type (PointType.CUBIC);

				ep.get_left_handle ().set_point_type (PointType.LINE_CUBIC);
				
				if (i == 0 || (b[i - 1].type == 'z')) {
					ep.get_left_handle ().set_point_type (last_type);
					ep.get_left_handle ().move_to_coordinate (last_x, last_y);
				} else {
					if (b[i - 1].type == 'C' || b[i - 1].type == 'S') {
						ep.get_left_handle ().set_point_type (PointType.CUBIC);
						ep.get_left_handle ().move_to_coordinate (b[i + 1].x1, b[i + 1].y1);
					} 
					
					if (b[i + 1].type == 'C' || b[i - 1].type == 'S') {
						ep.get_right_handle ().set_point_type (PointType.CUBIC);
						ep.get_right_handle ().move_to_coordinate (b[i + 1].x0, b[i + 1].y0);
					} else if (b[i + 1].type == 'L' || b[i + 1].type == 'M') {
						ep.get_right_handle ().set_point_type (PointType.LINE_CUBIC);					
					}
				}
			}

			if (b[i].type == 'L') {
				return_val_if_fail (i != 0, path_list);
				
				ep = path.add (b[i].x0, b[i].y0);
				ep.set_point_type (PointType.CUBIC);
				ep.get_right_handle ().set_point_type (PointType.LINE_CUBIC);
				ep.get_left_handle ().set_point_type (PointType.LINE_CUBIC);

				if (b[i + 1].type == 'L' || b[i + 1].type == 'M' || b[i + 1].type == 'z') {
					ep.get_right_handle ().set_point_type (PointType.LINE_CUBIC);
				}

				if (b[i -1].type == 'L' || b[i - 1].type == 'M') {
					ep.get_left_handle ().set_point_type (PointType.LINE_CUBIC);
				}
			}
			
			if (b[i].type == 'Q') {
				return_val_if_fail (i != 0, path_list);

				ep.set_point_type (PointType.QUADRATIC);
				
				ep.get_right_handle ().set_point_type (PointType.QUADRATIC);
				ep.get_right_handle ().move_to_coordinate (b[i].x0, b[i].y0);
				
				if (b[i + 1].type != 'z') {
					ep = path.add (b[i].x1, b[i].y1);

					ep.get_left_handle ().set_point_type (PointType.QUADRATIC);
					ep.get_left_handle ().move_to_coordinate (b[i].x0, b[i].y0);
				}
			}
	
			if (b[i].type == 'C' || b[i].type == 'S') {
				return_val_if_fail (i != 0, path_list);

				ep.set_point_type (PointType.CUBIC);
				
				ep.get_right_handle ().set_point_type (PointType.CUBIC);
				ep.get_right_handle ().move_to_coordinate (b[i].x0, b[i].y0);
				
				if (b[i].type == 'S') {
					smooth_points.add (ep);
				}
				
				if (b[i + 1].type != 'z') {
					ep = path.add (b[i].x2, b[i].y2);

					ep.get_left_handle ().set_point_type (PointType.CUBIC);
					ep.get_left_handle ().move_to_coordinate (b[i].x1, b[i].y1);
				}
			}
		}

		foreach (EditPoint e in smooth_points) {
			e.set_point_type (PointType.LINE_DOUBLE_CURVE);
			e.get_right_handle ().set_point_type (PointType.LINE_DOUBLE_CURVE);
			e.get_left_handle ().set_point_type (PointType.LINE_DOUBLE_CURVE);
		}

		foreach (EditPoint e in smooth_points) {
			path.recalculate_linear_handles_for_point (e);
		}
		
		for (int i = 0; i < 3; i++) {
			foreach (EditPoint e in smooth_points) {
				e.set_tie_handle (true);
				e.process_tied_handle ();
			}
		}
		
		if (path.points.size > 0) {
			path_list.add (path);
		}

		foreach (Path p in path_list.paths) {
			p.remove_points_on_points ();
		}
				
		return path_list;
	}

	PathList create_paths_illustrator (BezierPoints[] b, int num_b) {
		Path path;
		PathList path_list = new PathList ();
		EditPoint ep;
		bool first_point = true;
		double first_left_x, first_left_y;
		Gee.ArrayList<EditPoint> smooth_points = new Gee.ArrayList<EditPoint> ();
		
		if (num_b > b.length) {
			warning ("num_b > b.length: $num_b > $(b.length)");
			return path_list;
		}
		
		path = new Path ();
				
		if (num_b <= 1) {
			warning ("No SVG data");
			return path_list;
		}
		
		first_left_x = 0;
		first_left_y = 0;

		ep = new EditPoint ();
		
		for (int i = 0; i < num_b; i++) {
			if (b[i].type == '\0') {
				warning ("Parser error.");
				return path_list;
			} else if (b[i].type == 'z') {
				path.close ();
				path.create_list ();
				
				int first_index = 1;

				for (int j = i - 1; j >= 1; j--) {
					if (b[j].type == 'z') {
						first_index = j + 1; // from z to M 
					}
				}
				
				if (b[first_index].type == 'C' || b[first_index].type == 'S') {
					return_val_if_fail (path.points.size != 0, path_list);
					ep = path.points.get (path.points.size - 1);
					
					if (b[i - 1].type != 'L' ) {
						ep.get_right_handle ().set_point_type (PointType.CUBIC);
						ep.get_right_handle ().move_to_coordinate (b[first_index].x0, b[first_index].y0);
					}
				} else if (b[first_index].type == 'L') {
					return_val_if_fail (path.points.size != 0, path_list);
					ep = path.points.get (path.points.size - 1);
					ep.get_right_handle ().set_point_type (PointType.LINE_CUBIC);
					path.recalculate_linear_handles_for_point (ep);
				} else {
					warning ("Unexpected type: %s", (!) b[first_index].type.to_string ());
				}
				
				path.recalculate_linear_handles ();
				path_list.add (path);
				
				path = new Path ();
				first_point = true;				
			} else if (b[i].type == 'L' || b[i].type == 'M') {

				if (first_point) {
					first_left_x = b[i].x0;
					first_left_y = b[i].y0;
				}
				
				ep = path.add (b[i].x0, b[i].y0);
				ep.set_point_type (PointType.CUBIC); // TODO: quadratic
				ep.get_right_handle ().set_point_type (PointType.LINE_CUBIC);

				ep.get_left_handle ().set_point_type (PointType.CUBIC);
				ep.get_left_handle ().move_to_coordinate (b[i].x0 - 0.00001, b[i].y0 - 0.00001);
				
				if (b[i + 1].type == 'C' || b[i + 1].type == 'S') {
					return_val_if_fail (i + 1 < num_b, path_list);
					ep.get_right_handle ().set_point_type (PointType.CUBIC);
					ep.get_right_handle ().move_to_coordinate (b[i + 1].x0, b[i + 1].y0);
				}
				
				first_point = false;
			} else if (b[i].type == 'Q') {
				warning ("Illustrator does not support quadratic control points.");
				warning (@"$(b[i])\n");
			} else if (b[i].type == 'C' || b[i].type == 'S') {
				
				if (first_point) {
					first_left_x = b[i].x0;
					first_left_y = b[i].y0;
				}

				ep = path.add (b[i].x2, b[i].y2);
				ep.set_point_type (PointType.CUBIC);

				ep.get_right_handle ().set_point_type (PointType.CUBIC);
				ep.get_left_handle ().set_point_type (PointType.CUBIC);

				ep.get_left_handle ().move_to_coordinate (b[i].x1, b[i].y1);

				if (b[i].type == 'S') {
					smooth_points.add (ep);
				}		

				if (b[i + 1].type != 'z' && i != num_b - 1) {
					ep.get_right_handle ().move_to_coordinate (b[i + 1].x0, b[i + 1].y0);
				} else {
					ep.get_right_handle ().move_to_coordinate (first_left_x, first_left_y);
				}
				
				first_point = false;
			} else {
				warning ("Unknown control point type.");
				warning (@"$(b[i])\n");
			}
		}
		
		foreach (EditPoint e in smooth_points) {
			e.set_point_type (PointType.LINE_CUBIC);
			e.get_right_handle ().set_point_type (PointType.LINE_CUBIC);
			e.get_left_handle ().set_point_type (PointType.LINE_CUBIC);
		}

		foreach (EditPoint e in smooth_points) {
			path.recalculate_linear_handles_for_point (e);
		}
		
		for (int i = 0; i < 3; i++) {
			foreach (EditPoint e in smooth_points) {
				e.set_tie_handle (true);
				e.get_right_handle ().set_point_type (PointType.CUBIC);
				e.get_left_handle ().set_point_type (PointType.CUBIC);
				e.process_tied_handle ();
			}
		}
				
		if (path.points.size > 0) {
			path_list.add (path);
		}
		
		foreach (Path p in path_list.paths) {
			p.remove_points_on_points ();
		}
		
		return path_list;
	}
	
	public static double parse_double (string? s) {
		if (unlikely (is_null (s))) {
			warning ("Got null instead of expected string.");
			return 0;
		}
		
		if (unlikely (!is_point ((!) s))) {
			warning (@"Expecting a double got: $((!) s)");
			return 0;
		}
		
		string d = (!) s;
		d = d.replace ("px", "");
		
		return double.parse (d);
	}
	
	static bool is_point (string? s) {
		if (s == null) {
			warning ("s is null");
			return false;
		}
		
		return double.try_parse ((!) s);
	}
	
	Path parse_poly_data (string polygon_points) {
		string data = SvgFile.add_separators (polygon_points);
		string[] c = data.split (" ");
		Path path;
		BezierPoints[] bezier_points = new BezierPoints[c.length + 1];
		int bi;
		Glyph g;
		EditPoint ep;
		
		bi = 0;
		for (int i = 0; i < c.length - 1; i += 2) {	
			if (i + 1 >= c.length) {
				warning ("No y value.");
				break;
			}

			if (bi >= bezier_points.length) {
				warning ("End of bezier_points");
				break;
			}

			bezier_points[bi] = new BezierPoints ();
			bezier_points[bi].type = 'L';
			bezier_points[bi].x0 = parse_double (c[i]);
			bezier_points[bi].y0 = -parse_double (c[i + 1]);
			bi++;
		}
			
		g = MainWindow.get_current_glyph ();
		move_and_resize (bezier_points, bi, false, 1, g);
		
		path = new Path ();
		for (int i = 0; i < bi; i++) {	
			ep = path.add (bezier_points[i].x0, bezier_points[i].y0);
			ep.set_point_type (PointType.LINE_CUBIC);
		}
		
		path.create_list ();
		path.recalculate_linear_handles ();
		
		return path;
	}

	public static EmbeddedSvg parse_embedded_svg_file (string path) {
		string xml_data;
		
		try {
			FileUtils.get_contents (path, out xml_data);
			return parse_embedded_svg_data (xml_data);
		} catch (GLib.Error error) {
			warning (error.message);
		}
		
		SvgDrawing drawing = new SvgDrawing ();
		return new EmbeddedSvg (drawing);
	}

	public static EmbeddedSvg parse_embedded_svg_data (string xml_data) {
		XmlTree tree = new XmlTree (xml_data);
		SvgDrawing drawing = new SvgDrawing ();	
		SvgFile svg_file = new SvgFile (); 

		XmlElement root = tree.get_root ();
		drawing = svg_file.parse_svg_file (root);
		EmbeddedSvg svg = new EmbeddedSvg (drawing);
		svg.svg_data = xml_data;
		return svg;
	}

	/** Convert an SVG arc instruction to a Beziér path. */
	public static void add_arc_points (BezierPoints[] bezier_points, ref int bi, 
		double x0, double y0, double rx, double ry, double angle,
		bool largeArcFlag, bool sweepFlag, double x, double y) {
		
		double angleStart, angleExtent;
		double s, step, theta;
		double cx, cy;
		
		cx = 0;
		cy = 0;
		
		// Approximate the path with Beziér points
		SvgBird.get_arc_arguments (x0, y0, rx, ry, angle, largeArcFlag, sweepFlag, x, y,
			out angleStart, out angleExtent, out cx, out cx);
		
		s = (angleExtent > 0) ? 1 : -1;
		step = fabs (angleExtent) / (2 * fabs (angleExtent));

		theta = PI - angleStart - angleExtent;
		
		bezier_points[bi].type = 'C';
		bezier_points[bi].svg_type = 'a';

		bezier_points[bi].x0 = cx + rx * cos (theta);
		bezier_points[bi].y0 = cy + ry * sin (theta);
		
		bi++;
						
		for (double a = 0; a < fabs (angleExtent); a += step) {
			theta = PI - angleStart - angleExtent + s * a;

			return_if_fail (0 <= bi < bezier_points.length);

			bezier_points[bi].type = 'S';
			bezier_points[bi].svg_type = 'a';

			bezier_points[bi].x0 = cx + rx * cos (theta);
			bezier_points[bi].y0 = cy + ry * sin (theta);

			bezier_points[bi].x1 = cx + rx * cos (theta + 1 * step / 4);
			bezier_points[bi].y1 = cy + ry * sin (theta + 1 * step / 4);
			
			bezier_points[bi].x2 = cx + rx * cos (theta + 2 * step / 4);
			bezier_points[bi].y2 = cy + ry * sin (theta + 2 * step / 4);
							
			bi++;
		}
	}
}

}
