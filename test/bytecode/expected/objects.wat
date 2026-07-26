;; ---- globals ----
  (global 0 (mut lox) $clock)
  (global 1 (mut lox) $Base)
  (global 2 (mut lox) $Derived)
  (global 3 lox (nil))
  (global 4 lox (1))
  (global 5 lox (2))
;; ---- names ----
  [0] Base
  [1] m
  [2] Derived
  [3] init
  [4] v

(func 30 $<script> (param lox) (local lox lox)  ;; 1:1-1:1
2:1      |0      i32.const 0
2:1      |2      call 25  ;; lox.class
2:1      |4      i32.const 31
2:1      |6      i32.const 0
2:1      |8      call 21  ;; lox.closure
2:14     |10     i32.const 1
2:14     |12     call 27  ;; lox.method
2:1      |14     global.set 1  ;; $Base
3:1      |16     i32.const 2
3:1      |18     call 25  ;; lox.class
3:17     |20     global.get 1  ;; $Base
3:17     |22     i32.const 1
3:17     |24     call 15  ;; lox.check_global
3:1      |26     local.tee 2
3:1      |28     call 26  ;; lox.inherit
3:1      |30     global.get 3  ;; nil
3:1      |32     call 17  ;; lox.cell_new
3:1      |34     local.set 1
3:1      |36     local.get 1
3:1      |38     local.get 2
3:1      |40     call 19  ;; lox.cell_set
3:1      |42     drop
3:1      |43     i32.const 32
3:1      |45     i32.const 0
3:1      |47     call 21  ;; lox.closure
4:3      |49     i32.const 3
4:3      |51     call 27  ;; lox.method
4:3      |53     local.get 1
4:3      |55     i32.const 33
4:3      |57     i32.const 1
4:3      |59     call 21  ;; lox.closure
5:3      |61     i32.const 1
5:3      |63     call 27  ;; lox.method
3:1      |65     global.set 2  ;; $Derived
7:1      |67     global.get 2  ;; $Derived
7:1      |69     i32.const 2
7:1      |71     call 15  ;; lox.check_global
7:9      |73     global.get 4  ;; 1
7:1      |75     i32.const 1
7:1      |77     call 14  ;; lox.call
7:14     |79     global.get 5  ;; 2
7:1      |81     i32.const 1
7:1      |83     i32.const 1
7:1      |85     call 24  ;; lox.invoke
7:1      |87     drop
7:1      |88     global.get 3  ;; nil
7:1      |90   end
)

(func 31 $m (param lox lox)  ;; 2:14-2:32
2:28     |0      local.get 1
2:21     |2      return
2:21     |3      global.get 3  ;; nil
2:21     |5    end
)

(func 32 $init (param lox lox)  ;; 4:3-4:26
4:13     |0      local.get 0
4:22     |2      local.get 1
4:13     |4      i32.const 4
4:13     |6      call 23  ;; lox.set_field
4:13     |8      drop
4:13     |9      local.get 0
4:13     |11   end
)

(func 33 $m (param lox lox)  ;; 5:3-5:39 captures local1
5:17     |0      local.get 0
5:25     |2      local.get 1
5:25     |4      i32.const 0
5:25     |6      call 20  ;; lox.upvalue
5:25     |8      call 18  ;; lox.cell_get
5:17     |10     i32.const 1
5:17     |12     i32.const 1
5:17     |14     call 29  ;; lox.invoke_super
5:30     |16     local.get 0
5:30     |18     i32.const 4
5:30     |20     call 22  ;; lox.get_field
5:17     |22     call 3  ;; lox.add
5:10     |24     return
5:10     |25     global.get 3  ;; nil
5:10     |27   end
)
