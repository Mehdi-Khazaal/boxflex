--  Boxflex.Layout with no content measurement. See Boxflex.Measure_None.

with Boxflex.Layout;
with Boxflex.Measure_None;

package Boxflex.Layout_Plain is
  new Boxflex.Layout (Measure => Boxflex.Measure_None.Measure);
