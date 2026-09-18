/* ============================================
   SPACER / ENTRETOISE — Générateur paramétrique
   Compatible MakerWorld Customizer
   ============================================ */

/* [Dimensions] */

// Diamètre intérieur nominal (M3=3, M4=4, M5=5...)
inner_diameter = 5;

// Épaisseur de paroi (mm)
wall_thickness = 2;

// Hauteur / longueur (mm)
height = 10;

/* [Tolérance] */

// Matériau utilisé
material = 0; // [0:PLA (+0.2mm), 1:PETG (+0.3mm), 2:Manuel]

// Tolérance manuelle (uniquement si matériau = Manuel)
manual_tolerance = 0.2;

/* [Options] */

// Chanfrein entrée/sortie (0 = désactivé)
chamfer = 0.4;

// Qualité des cercles (segments)
$fn = 72;


/* ============================================
   LOGIQUE INTERNE
   ============================================ */

tol = (material == 0) ? 0.2 :
      (material == 1) ? 0.3 :
      manual_tolerance;

inner_r = (inner_diameter / 2) + (tol / 2);
outer_r = inner_r + wall_thickness;


/* ============================================
   MODULE PRINCIPAL
   ============================================ */

module spacer() {
    difference() {
        // Corps extérieur
        cylinder(h = height, r = outer_r, center = false);

        // Alésage intérieur (légèrement prolongé pour éviter artefacts booléens)
        translate([0, 0, -0.01])
            cylinder(h = height + 0.02, r = inner_r, center = false);

        // Chanfrein inférieur
        if (chamfer > 0) {
            translate([0, 0, -0.01])
                cylinder(
                    h = chamfer + 0.01,
                    r1 = inner_r + chamfer,
                    r2 = inner_r,
                    center = false
                );
        }

        // Chanfrein supérieur
        if (chamfer > 0) {
            translate([0, 0, height - chamfer])
                cylinder(
                    h = chamfer + 0.01,
                    r1 = inner_r,
                    r2 = inner_r + chamfer,
                    center = false
                );
        }
    }
}

spacer();


/* ============================================
   RÉSUMÉ DIMENSIONS (console OpenSCAD)
   ============================================ */

echo(str("=== SPACER RÉSUMÉ ==="));
echo(str("Ø intérieur nominal : ", inner_diameter, " mm"));
echo(str("Tolérance appliquée : +", tol, " mm"));
echo(str("Ø intérieur réel    : ", inner_diameter + tol, " mm"));
echo(str("Ø extérieur         : ", outer_r * 2, " mm"));
echo(str("Hauteur             : ", height, " mm"));
echo(str("Épaisseur paroi     : ", wall_thickness, " mm"));
