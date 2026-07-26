;; ---- globals ----
  (global 0 (mut lox) $clock)
  (global 1 (mut lox) $i)
  (global 2 lox (0))
  (global 3 lox (3))
  (global 4 lox (1))
  (global 5 lox ("one"))
  (global 6 lox ("other"))
  (global 7 lox (nil))

(func 30 $<script> (param lox)  ;; 1:1-1:1
2:9      |0      global.get 2  ;; 0
2:1      |2      global.set 1  ;; $i
3:1      |4      block
3:1      |6        loop
3:8      |8          global.get 1  ;; $i
3:8      |10         i32.const 1
3:8      |12         call 15  ;; lox.check_global
3:12     |14         global.get 3  ;; 3
3:8      |16         call 9  ;; lox.lt
3:1      |18         call 0  ;; lox.truthy
3:1      |20         i32.eqz
3:1      |21         br_if 1
4:7      |23         global.get 1  ;; $i
4:7      |25         i32.const 1
4:7      |27         call 15  ;; lox.check_global
4:12     |29         global.get 4  ;; 1
4:7      |31         call 7  ;; lox.eq
4:3      |33         call 0  ;; lox.truthy
4:3      |35         if
4:21     |37           global.get 5  ;; "one"
4:15     |39           call 13  ;; lox.print
4:15     |41         else
4:39     |42           global.get 6  ;; "other"
4:33     |44           call 13  ;; lox.print
4:33     |46         end
5:7      |47         global.get 1  ;; $i
5:7      |49         i32.const 1
5:7      |51         call 15  ;; lox.check_global
5:11     |53         global.get 4  ;; 1
5:7      |55         call 3  ;; lox.add
5:3      |57         i32.const 1
5:3      |59         call 16  ;; lox.set_global
5:3      |61         drop
5:3      |62         br 0
5:3      |64       end
5:3      |65     end
5:3      |66     global.get 7  ;; nil
5:3      |68   end
)
