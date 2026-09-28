--  boxflex: fixed-point flexbox layout engine with proven geometry.
--
--  Root package. Everything below shares these fundamental types.
--  No floating point anywhere: layouts must be deterministic and
--  bit-identical on every target, including bare-metal ones.

package Boxflex with SPARK_Mode, Pure is

   ---------------------------------------------------------------------
   --  Fixed-point coordinate: Q23.8 (23 integer bits, 8 fraction bits)
   ---------------------------------------------------------------------

   Precision : constant := 1.0 / 256.0;  --  2**(-8)

   type Coord is delta Precision range -8_388_608.0 .. 8_388_607.99609375
     with Small => Precision;  --  +/- 2**23
   --  Signed position or offset, in device-independent pixels.
   --  Resolution is 1/256 px. Range is about +/- 8.3 million px.

   subtype Length is Coord range 0.0 .. 4_194_304.0;  --  2**22
   --  Non-negative extent (width, height, margin, padding, gap).
   --  Capped at 2**22 so that two Lengths can always be added, and a
   --  Length can always be added to any Coord in the first half of
   --  the Coord range, without overflow. See Geometry preconditions.

   Max_Pos : constant Coord := Coord'Last - Length'Last;
   --  Any Length can be added to a Coord at most Max_Pos without
   --  overflow. Layout code keeps every origin and position at or
   --  below Max_Pos (saturating), which is what makes the far edges of
   --  every rect computable.

   ---------------------------------------------------------------------
   --  Unit-less ratio: Q10.10
   ---------------------------------------------------------------------

   Ratio_Precision : constant := 1.0 / 1024.0;  --  2**(-10)

   type Ratio is delta Ratio_Precision range 0.0 .. 1024.0
     with Small => Ratio_Precision;
   --  Used for flex-grow, flex-shrink and percentages.

   subtype Fraction is Ratio range 0.0 .. 1.0;
   --  A percentage expressed as 0.0 .. 1.0 (50% is 0.5).

   ---------------------------------------------------------------------
   --  Bounded node identifiers
   ---------------------------------------------------------------------

   Max_Nodes : constant := 256;
   --  Hard upper bound on the number of nodes in one layout tree.
   --  Bounded on purpose: no heap, no access types, provable.
   --  Raise it if a real UI needs more; keep it a compile-time constant.

   type Node_Id is range 0 .. Max_Nodes;

   No_Node : constant Node_Id := 0;

   subtype Valid_Node_Id is Node_Id range 1 .. Max_Nodes;

end Boxflex;
