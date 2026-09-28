--  The trivial measurement: nothing has intrinsic content. Leaves are
--  as big as their Width/Height styles say, and no bigger. Enough for
--  the showcase and for UIs made of boxes and sprites of known size.

with Boxflex.Geometry; use Boxflex.Geometry;
with Boxflex.Tree;     use Boxflex.Tree;

package Boxflex.Measure_None with SPARK_Mode is

   pragma Warnings (Off, "formal parameter * is not referenced");
   function Measure
     (T : Layout_Tree; N : Node_Id; Available : Size) return Size
   is (Zero_Size);
   pragma Warnings (On, "formal parameter * is not referenced");

end Boxflex.Measure_None;
