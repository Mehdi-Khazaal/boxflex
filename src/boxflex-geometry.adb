package body Boxflex.Geometry with SPARK_Mode is

   -----------
   -- Inset --
   -----------

   function Inset
     (R                        : Rect;
      Left, Top, Right, Bottom : Length) return Rect
   is
      --  Length is capped at 2**22, so Width - Left - Right stays
      --  inside Coord even when it goes negative; we clamp afterwards.
      W : constant Coord := R.Extent.Width  - Left - Right;
      H : constant Coord := R.Extent.Height - Top  - Bottom;
   begin
      return
        (Origin => (X => R.Origin.X + Left, Y => R.Origin.Y + Top),
         Extent => (Width  => (if W < 0.0 then 0.0 else W),
                    Height => (if H < 0.0 then 0.0 else H)));
   end Inset;

   ---------------
   -- Translate --
   ---------------

   function Translate (R : Rect; DX, DY : Coord) return Rect is
     (Origin => (X => R.Origin.X + DX, Y => R.Origin.Y + DY),
      Extent => R.Extent);

end Boxflex.Geometry;
