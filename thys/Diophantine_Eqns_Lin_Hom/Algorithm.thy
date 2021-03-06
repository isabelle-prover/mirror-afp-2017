(*
Author:  Christian Sternagel <c.sternagel@gmail.com>
License: LGPL
*)

section \<open>Computing Minimal Complete Sets of Solutions\<close>

theory Algorithm
  imports
    Linear_Diophantine_Equations
    Minimize_Wrt
begin

(*TODO: move*)
lemma all_Suc_le_conv: "(\<forall>i\<le>Suc n. P i) \<longleftrightarrow> P 0 \<and> (\<forall>i\<le>n. P (Suc i))"
  by (metis less_Suc_eq_0_disj nat_less_le order_refl)

(*TODO: move*)
lemma concat_map_filter_filter:
  assumes "\<And>x. x \<in> set xs \<Longrightarrow> \<not> Q x \<Longrightarrow> filter P (f x) = []"
  shows "concat (map (filter P \<circ> f) (filter Q xs)) = concat (map (filter P \<circ> f) xs)"
  using assms by (induct xs) simp_all

(*TODO: move*)
lemma filter_pairs_conj:
  "filter (\<lambda>(x, y). P x y \<and> Q y) xs = filter (\<lambda>(x, y). P x y) (filter (Q \<circ> snd) xs)"
  by (induct xs) auto

(*TODO: move*)
lemma concat_map_filter:
  "concat (map f (filter P xs)) = concat (map (\<lambda>x. if P x then f x else []) xs)"
  by (induct xs) simp_all


subsection \<open>Lexicographic Enumeration of Potential Solutions\<close>

fun rlex2 :: "(nat list \<times> nat list) \<Rightarrow> (nat list \<times> nat list) \<Rightarrow> bool"  (infix "<\<^sub>r\<^sub>l\<^sub>e\<^sub>x\<^sub>2" 50)
  where
    "(xs, ys) <\<^sub>r\<^sub>l\<^sub>e\<^sub>x\<^sub>2 (us, vs) \<longleftrightarrow> xs @ ys <\<^sub>r\<^sub>l\<^sub>e\<^sub>x us @ vs"

lemma rlex2_irrefl:
  "\<not> x <\<^sub>r\<^sub>l\<^sub>e\<^sub>x\<^sub>2 x"
  by (cases x) (auto simp: rlex_irrefl)

lemma rlex2_not_sym: "x <\<^sub>r\<^sub>l\<^sub>e\<^sub>x\<^sub>2 y \<Longrightarrow> \<not> y <\<^sub>r\<^sub>l\<^sub>e\<^sub>x\<^sub>2 x"
  using rlex_not_sym by (cases x; cases y; simp)

lemma less_imp_rlex2: "\<not> (case x of (x, y) \<Rightarrow> \<lambda>(u, v). \<not> x @ y <\<^sub>v u @ v) y \<Longrightarrow> x <\<^sub>r\<^sub>l\<^sub>e\<^sub>x\<^sub>2 y"
  using less_imp_rlex by (cases x; cases y; auto)

lemma rlex2_trans:
  assumes "x <\<^sub>r\<^sub>l\<^sub>e\<^sub>x\<^sub>2 y"
    and "y <\<^sub>r\<^sub>l\<^sub>e\<^sub>x\<^sub>2 z"
  shows "x <\<^sub>r\<^sub>l\<^sub>e\<^sub>x\<^sub>2 z"
  using assms
proof -
  obtain x1 x2 y1 y2 z1 z2 where "(x1, x2) = x" and "(y1, y2) = y" and "(z1, z2) = z"
    using prod.collapse by blast
  then show ?thesis
    using assms rlex_def
      lex_trans[of "rev (x1 @ x2)" "rev (y1 @ y2)" "rev (z1 @ z2)"]
    by (auto)
qed

fun alls
  where
    "alls B [] = [([], 0)]"
  | "alls B (a # as) = [(x # xs, s + a * x). (xs, s) \<leftarrow> alls B as, x \<leftarrow> [0 ..< B + 1]]"

lemma alls_ne [simp]:
  "alls B as \<noteq> []"
  by (induct as)
    (auto, metis (no_types, lifting) append_is_Nil_conv case_prod_conv list.set_intros(1)
     neq_Nil_conv old.prod.exhaust)

lemma in_alls:
  assumes "(xs, s) \<in> set (alls B as)"
  shows "(\<forall>x\<in>set xs. x \<le> B) \<and> s = as \<bullet> xs \<and> length xs = length as"
  using assms by (induct as arbitrary: xs s) auto

lemma in_alls':
  assumes "\<forall>x\<in>set xs. x \<le> B" and "length xs = length as"
  shows "(xs, as \<bullet> xs) \<in> set (alls B as)"
  using assms(2, 1)
  apply (induct xs as rule: list_induct2)
   apply auto
  apply (rule_tac x = "(xs, ys \<bullet> xs)" in bexI)
   apply auto
  done

lemma concat_map_nth0: "xs \<noteq> [] \<Longrightarrow> f (xs ! 0) \<noteq> [] \<Longrightarrow> concat (map f xs) ! 0 = f (xs ! 0) ! 0"
  by (induct xs) (auto simp: nth_append)

lemma alls_nth0 [simp]: "alls A as ! 0 = (zeroes (length as), 0)"
  by (induct as) (auto simp: nth_append concat_map_nth0)

lemma alls_Cons_tl_conv: "alls A as = (zeroes (length as), 0) # tl (alls A as)"
  by (rule nth_equalityI) (auto simp: nth_Cons nth_tl split: nat.splits)

lemma sorted_wrt_alls:
  "sorted_wrt (op <\<^sub>r\<^sub>l\<^sub>e\<^sub>x) (map fst (alls B xs))"
  by (induct xs) (auto simp: map_concat rlex_Cons sorted_wrt_append
      intro!: sorted_wrt_concat_map sorted_wrt_map_mono [of "op <"])

definition "alls2 A B a b = [(xs, ys). ys \<leftarrow> alls B b, xs \<leftarrow> alls A a]"

value "alls2 2 1 [1,1] [2]"

lemma alls2_ne [simp]:
  "alls2 A B a b \<noteq> []"
  by (auto simp: alls2_def) (metis alls_ne list.set_intros(1) neq_Nil_conv surj_pair)

lemma in_alls2:
  assumes "((xs, s), (ys, t)) \<in> set (alls2 A B as bs)"
  shows "(\<forall>x\<in>set xs. x \<le> A) \<and> (\<forall>y\<in>set ys. y \<le> B) \<and> s = as \<bullet> xs \<and> t = bs \<bullet> ys \<and>
    length xs = length as \<and> length ys = length bs"
  using assms by (auto simp: alls2_def dest: in_alls)

lemma in_alls2':
  assumes "\<forall>x\<in>set xs. x \<le> A" and "\<forall>y\<in>set ys. y \<le> B"
    and "length xs = length as" and "length ys = length bs"
  shows "((xs, as \<bullet> xs), (ys, bs \<bullet> ys)) \<in> set (alls2 A B as bs)"
  using assms by (auto simp: alls2_def in_alls' dest: in_alls')

lemma alls2_nth0 [simp]: "alls2 A B as bs ! 0 = ((zeroes (length as), 0), (zeroes (length bs), 0))"
  by (auto simp: alls2_def concat_map_nth0)

lemma alls2_Cons_tl_conv: "alls2 A B as bs =
  ((zeroes (length as), 0), (zeroes (length bs), 0)) # tl (alls2 A B as bs)"
  apply (rule nth_equalityI)
   apply (auto simp: alls2_def nth_Cons nth_tl length_concat concat_map_nth0 split: nat.splits)
  apply (cases "alls B bs"; simp)
  done

lemma sorted_wrt_alls2:
  "sorted_wrt (op <\<^sub>r\<^sub>l\<^sub>e\<^sub>x\<^sub>2) (map (\<lambda>(x, y). (fst x, fst y)) (alls2 A B as bs))"
  apply (rule sorted_wrt_map_mono [of "\<lambda>(x, y) (u, v). (fst x, fst y) <\<^sub>r\<^sub>l\<^sub>e\<^sub>x\<^sub>2 (fst u, fst v)"])
   apply (auto simp: alls2_def map_concat)
  apply (fold rlex2.simps)
  apply (rule sorted_wrt_concat_map_map)
     apply (rule sorted_wrt_map_distr, rule sorted_wrt_alls)
    apply (rule sorted_wrt_map_distr, rule sorted_wrt_alls)
   apply (auto simp: rlex_def intro: lex_append_left lex_append_right dest!: in_alls)
  done

definition "generate mx my a b = map (\<lambda>(x, y). (fst x, fst y)) (alls2 mx my a b)"

lemma sorted_wrt_generate:
  "sorted_wrt (op <\<^sub>r\<^sub>l\<^sub>e\<^sub>x\<^sub>2) (generate A B a b)"
  by (auto simp: generate_def sorted_wrt_alls2)

lemma generate_nth0 [simp]:
  "generate A B a b ! 0 = (zeroes (length a), zeroes (length b))"
  by (auto simp: generate_def)

definition "cond_cons P = (\<lambda>(ys, s). case ys of [] \<Rightarrow> True | ys \<Rightarrow> P ys s)"

lemma cond_cons_simp [simp]:
  "cond_cons P ([], s) = True"
  "cond_cons P (x # xs, s) = P (x # xs) s"
  by (auto simp: cond_cons_def)

fun suffs
  where
    "suffs P as (xs, s) \<longleftrightarrow>
      length xs = length as \<and>
      s = as \<bullet> xs \<and>
      (\<forall>i\<le>length xs. cond_cons P (drop i xs, drop i as \<bullet> drop i xs))"
declare suffs.simps [simp del]

lemma suffs_Nil [simp]: "suffs P [] ([], s) \<longleftrightarrow> s = 0"
  by (auto simp: suffs.simps)

lemma suffs_Cons:
  "suffs P (a # as) (x # xs, s) \<longleftrightarrow>
    s = a * x + as \<bullet> xs \<and> cond_cons P (x # xs, s) \<and> suffs P as (xs, as \<bullet> xs)"
  apply (auto simp: suffs.simps cond_cons_def split: list.splits)
    apply force
   apply (metis Suc_le_mono drop_Suc_Cons)
  by (metis One_nat_def Suc_le_mono Suc_pred dotprod_Cons drop_Cons' le_0_eq not_le_imp_less)


subsection \<open>The Algorithm\<close>

fun maxne0_impl
  where
    "maxne0_impl [] a = 0"
  | "maxne0_impl x [] = 0"
  | "maxne0_impl (x#xs) (a#as) = (if x > 0 then max a (maxne0_impl xs as) else maxne0_impl xs as)"

lemma maxne0_impl:
  assumes "length x = length a"
  shows "maxne0_impl x a = maxne0 x a"
  using assms by (induct x a rule: list_induct2) (auto)

lemma maxne0_impl_le:
  "maxne0_impl x a \<le> Max (set (a::nat list))"
  apply (induct x a rule: maxne0_impl.induct)
  apply (auto simp add: max.coboundedI2)
  by (metis List.finite_set Max_insert Nat.le0 le_max_iff_disj maxne0_impl.elims maxne0_impl.simps(2) set_empty)

context
  fixes a b :: "nat list"
begin

definition special_solutions :: "(nat list \<times> nat list) list"
  where
    "special_solutions = map (\<lambda>(i, j). sij a b i j) (List.product [0 ..< length a] [0 ..< length b])"

definition big_e :: "nat list \<Rightarrow> nat \<Rightarrow> nat list"
  where
    "big_e x j = map (\<lambda>i. eij a b i j - 1) (filter (\<lambda>i. x ! i \<ge> dij a b i j) [0 ..< length x])"

definition big_d :: "nat list \<Rightarrow> nat \<Rightarrow> nat list"
  where
    "big_d y i = map (\<lambda>j. dij a b i j - 1) (filter (\<lambda>j. y ! j \<ge> eij a b i j) [0 ..< length y])"

definition big_d' :: "nat list \<Rightarrow> nat \<Rightarrow> nat list"
  where
    "big_d' y i =
      (let l = length y; n = length b in
      if l > n then [] else
      (let k = n - l in
      map (\<lambda>j. dij a b i (j + k) - 1) (filter (\<lambda>j. y ! j \<ge> eij a b i (j + k)) [0 ..< length y])))"

definition maxy_impl :: "nat list \<Rightarrow> nat \<Rightarrow> nat"
  where
    "maxy_impl x j =
      (if j < length b \<and> big_e x j \<noteq> [] then Min (set (big_e x j))
      else Max (set a))"

definition maxx_impl :: "nat list \<Rightarrow> nat \<Rightarrow> nat"
  where
    "maxx_impl y i =
      (if i < length a \<and> big_d y i \<noteq> [] then Min (set (big_d y i))
      else Max (set b))"

definition maxx_impl' :: "nat list \<Rightarrow> nat \<Rightarrow> nat"
  where
    "maxx_impl' y i =
      (if i < length a \<and> big_d' y i \<noteq> [] then Min (set (big_d' y i))
      else Max (set b))"

definition cond_a :: "nat list \<Rightarrow> nat list \<Rightarrow> bool"
  where
    "cond_a xs ys \<longleftrightarrow> (\<forall>x\<in>set xs. x \<le> maxne0 ys b)"

definition cond_b :: "nat list \<Rightarrow> bool"
  where
    "cond_b xs \<longleftrightarrow> (\<forall>k\<le>length a.
      take k a \<bullet> take k xs \<le> b \<bullet> (map (maxy_impl (take k xs)) [0 ..< length b]))"

definition boundr_impl :: "nat list \<Rightarrow> nat list \<Rightarrow> bool"
  where
    "boundr_impl x y \<longleftrightarrow> (\<forall>j<length b. y ! j \<le> maxy_impl x j)"

definition cond_d :: "nat list \<Rightarrow> nat list \<Rightarrow> bool"
  where
    "cond_d xs ys \<longleftrightarrow> (\<forall>l\<le>length b. take l b \<bullet> take l ys \<le> a \<bullet> xs)"

definition pdprodr_impl :: "nat list \<Rightarrow> bool"
  where
    "pdprodr_impl ys \<longleftrightarrow> (\<forall>l\<le>length b.
      take l b \<bullet> take l ys \<le> a \<bullet> map (maxx_impl (take l ys)) [0 ..< length a])"

definition pdprodl_impl :: "nat list \<Rightarrow> nat list \<Rightarrow> bool"
  where
    "pdprodl_impl x y \<longleftrightarrow> (\<forall>k\<le>length a. take k a \<bullet> take k x \<le> b \<bullet> y)"

definition "boundl_impl x y \<longleftrightarrow> (\<forall>i<length a. x ! i \<le> maxx_impl y i)"

definition static_bounds
  where
    "static_bounds x y \<longleftrightarrow>
      (let mx = maxne0_impl y b; my = maxne0_impl x a in
      (\<forall>x\<in>set x. x \<le> mx) \<and> (\<forall>y\<in>set y. y \<le> my))"

definition "minimize = minimize_wrt (\<lambda>(x, y) (u, v). \<not> x @ y <\<^sub>v u @ v)"

definition "check = (\<lambda>(x, y).
  static_bounds x y \<and> a \<bullet> x = b \<bullet> y \<and> boundr_impl x y \<and> pdprodl_impl x y \<and> pdprodr_impl y)"

definition "non_special_solutions =
  (let
     max_x = Max (set b);
     max_y = Max (set a);
     all = tl (generate max_x max_y a b)
  in
  minimize (filter check all))"

definition "solve = special_solutions @ non_special_solutions"

end

lemma generate_ne [simp, intro]: "generate m n b c \<noteq> []"
  by (auto simp: generate_def)

lemma in_tl_generate: "x \<in> set (tl (generate m n c b)) \<Longrightarrow> x \<in> set (generate m n c b)"
  by (rule list.set_sel) simp

lemma big_e:
  "set (big_e a b xs j) = hlde_ops.Ej a b j xs"
  by (auto simp: hlde_ops.Ej_def big_e_def)

lemma big_d:
  "set (big_d a b ys i) = hlde_ops.Di a b i ys"
  by (auto simp: hlde_ops.Di_def big_d_def)

lemma big_d':
  "length ys \<le> length b \<Longrightarrow> set (big_d' a b ys i) = hlde_ops.Di' a b i ys"
  by (auto simp: hlde_ops.Di'_def big_d'_def Let_def)

lemma maxy_impl:
  "maxy_impl a b x j = hlde_ops.maxy a b x j"
  by (simp add: maxy_impl_def big_e hlde_ops.maxy_def set_empty [symmetric])

lemma maxx_impl:
  "maxx_impl a b y i = hlde_ops.maxx a b y i"
  by (simp add: maxx_impl_def big_d hlde_ops.maxx_def set_empty [symmetric])

lemma maxx_impl':
  assumes "length y \<le> length b"
  shows "maxx_impl' a b y i = hlde_ops.maxx' a b y i"
  by (simp add: maxx_impl'_def big_d' [OF assms] hlde_ops.maxx'_def set_empty [symmetric])

lemma (in hlde) cond_a [simp]: "cond_a b x y = cond_A x y"
  by (simp add: cond_a_def cond_A_def)

lemma (in hlde) cond_b [simp]: "cond_b a b x = cond_B x"
  using maxy_impl by (auto simp: cond_b_def cond_B_def) presburger+

lemma (in hlde) boundr_impl [simp]: "boundr_impl a b x y = boundr x y"
  by (simp add: boundr_impl_def boundr_def maxy_impl)

lemma (in hlde) cond_d [simp]: "cond_d a b x y = cond_D x y"
  by (simp add: cond_d_def cond_D_def)

lemma (in hlde) pdprodr_impl [simp]: "pdprodr_impl a b y = subprodr y"
  using maxx_impl by (auto simp: pdprodr_impl_def subprodr_def) presburger+

lemma (in hlde) pdprodl_impl [simp]: "pdprodl_impl a b x y = subprodl x y"
  by (simp add: pdprodl_impl_def subprodl_def)

lemma (in hlde) cond_bound_impl [simp]: "boundl_impl a b x y = boundl x y"
  by (simp add: boundl_impl_def boundl_def maxx_impl)

lemma (in hlde) check [simp]:
  "check a b =
    (\<lambda>(x, y). static_bounds a b x y \<and> a \<bullet> x = b \<bullet> y \<and> boundr x y \<and>
    subprodl x y \<and>
    subprodr y)"
  by (simp add: check_def)

text \<open>
  conditions B, C, and D from Huet as well as "subprodr" and "subprodl" are
  preserved by smaller solutions
\<close>
lemma (in hlde) le_imp_conds:
  assumes le: "u \<le>\<^sub>v x" "v \<le>\<^sub>v y"
    and len: "length x = m" "length y = n"
  shows "cond_B x \<Longrightarrow> cond_B u"
    and "boundr x y \<Longrightarrow> boundr u v"
    and "a \<bullet> u = b \<bullet> v \<Longrightarrow> cond_D x y \<Longrightarrow> cond_D u v"
    and "a \<bullet> u = b \<bullet> v \<Longrightarrow> subprodl x y \<Longrightarrow> subprodl u v"
    and "subprodr y \<Longrightarrow> subprodr v"
proof -
  assume B: "cond_B x"
  have "length u = m" using len and le by (auto)
  show "cond_B u"
  proof (unfold cond_B_def, intro allI impI)
    fix k
    assume k: "k \<le> m"
    moreover have *: "take k u \<le>\<^sub>v take k x" if "k \<le> m" for k
      using le and that by (intro le_take) (auto simp: len)
    ultimately have "take k a \<bullet> take k u \<le> take k a \<bullet> take k x"
      by (intro dotprod_le_right) (auto simp: len)
    also have "\<dots> \<le> b \<bullet> map (maxy (take k x)) [0..<n]"
      using k and B by (auto simp: cond_B_def)
    also have "\<dots> \<le> b \<bullet> map (maxy (take k u)) [0..<n]"
      using le_imp_maxy_ge [OF * [OF k]]
      using k by (auto simp: len intro!: dotprod_le_right less_eqI)
    finally show "take k a \<bullet> take k u \<le> b \<bullet> map (maxy (take k u)) [0..<n]" .
  qed
next
  assume subprodr: "subprodr y"
  have "length v = n" using len and le by (auto)
  show "subprodr v"
  proof (unfold subprodr_def, intro allI impI)
    fix l
    assume l: "l \<le> n"
    moreover have *: "take l v \<le>\<^sub>v take l y" if "l \<le> n" for l
      using le and that by (intro le_take) (auto simp: len)
    ultimately have "take l b \<bullet> take l v \<le> take l b \<bullet> take l y"
      by (intro dotprod_le_right) (auto simp: len)
    also have "\<dots> \<le> a \<bullet> map (maxx (take l y)) [0..<m]"
      using l and subprodr by (auto simp: subprodr_def)
    also have "\<dots> \<le> a \<bullet> map (maxx (take l v)) [0..<m]"
      using le_imp_maxx_ge [OF * [OF l]]
      using l by (auto simp: len intro!: dotprod_le_right less_eqI)
    finally show "take l b \<bullet> take l v \<le> a \<bullet> map (maxx (take l v)) [0..<m]" .
  qed
next
  assume C: "boundr x y"
  show "boundr u v"
    using le_imp_maxy_ge [OF \<open>u \<le>\<^sub>v x\<close>] and C and le
    by (auto simp: boundr_def len less_eq_def) (meson order_trans)
next
  assume "a \<bullet> u = b \<bullet> v" and "cond_D x y"
  then show "cond_D u v"
    using le by (auto simp: cond_D_def len le_length intro: dotprod_le_take)
next
  assume "a \<bullet> u = b \<bullet> v" and "subprodl x y"
  then show "subprodl u v"
    using le by (metis subprodl_def dotprod_le_take le_length len(1))
qed

lemma (in hlde) special_solutions [simp]:
  shows "set (special_solutions a b) = Special_Solutions"
proof -
  have "set (special_solutions a b) \<subseteq> Special_Solutions"
    by (auto simp: Special_Solutions_def special_solutions_def) (blast)
  moreover have "Special_Solutions \<subseteq> set (special_solutions a b)"
    by (auto simp: Special_Solutions_def special_solutions_def)
      (metis SigmaI atLeast0LessThan lessThan_iff pair_imageI)
  ultimately show ?thesis ..
qed

lemma set_generate:
  "set (generate mx my a b) = {(x, y). x \<le>\<^sub>v replicate (length a) mx \<and> y \<le>\<^sub>v replicate (length b) my}"
  (is "?L = ?R")
proof (intro equalityI subrelI)
  fix xs ys assume "(xs, ys) \<in> ?R"
  then have "\<forall>x\<in>set xs. x \<le> mx" and "\<forall>y\<in>set ys. y \<le> my"
    and "length xs = length a" and "length ys = length b"
    by (auto simp: less_eq_def in_set_conv_nth)
  from in_alls2' [OF this(1,2), of a b] and this(3,4)
  show "(xs, ys) \<in> ?L" by (force simp: generate_def)
qed (auto simp: generate_def less_eq_def dest: in_alls2)

lemma (in hlde) in_non_special_solutions:
  assumes "(x, y) \<in> set (non_special_solutions a b)"
  shows "(x, y) \<in> Solutions"
  using assms
  by (force dest: in_tl_generate dest: minimize_wrt_subset [THEN subsetD]
      simp: non_special_solutions_def Solutions_def minimize_def set_generate)

lemma generate_unique:
  assumes "i < length (generate A B a b)"
    and "j < length (generate A B a b)"
    and "i < j"
  shows "generate A B a b ! i \<noteq> generate A B a b ! j"
  using sorted_wrt_nth_less [OF sorted_wrt_generate assms]
    by (auto simp: rlex2_irrefl)

lemma zeroes_ni_generate_tl:
  "(zeroes (length a), zeroes (length b)) \<notin> set (tl (generate A B a b))"
proof -
  have "generate A B a b ! 0 = (zeroes (length a), zeroes (length b))" by (auto simp: generate_def)
  with generate_unique [of 0 A B a b] show ?thesis
    by (auto simp: in_set_conv_nth nth_tl)
      (metis One_nat_def Suc_eq_plus1 less_diff_conv zero_less_Suc)
qed

lemma generate_tl:
  "set (tl (generate A B a b)) =
    {(x, y). (x, y) \<noteq> (zeroes (length a), zeroes (length b)) \<and> (x, y) \<in> set (generate A B a b)}"
proof
  show "set (tl (generate A B a b))
        \<subseteq> {(x, y).(x, y) \<noteq> (zeroes (length a), zeroes (length b)) \<and> (x, y) \<in> set (generate A B a b)}"
    using in_tl_generate mem_Collect_eq zeroes_ni_generate_tl by auto
next
  have "(zeroes (length a), zeroes (length b)) = hd (generate A B a b)"
    by (simp add: hd_conv_nth)
  moreover have "set (generate A B a b) = set (tl (generate A B a b)) \<union> {(zeroes (length a), zeroes (length b))}"
    by (metis Un_empty_right Un_insert_right generate_ne calculation list.exhaust_sel list.simps(15))
  ultimately show " {(x, y). (x, y) \<noteq> (zeroes (length a), zeroes (length b)) \<and> (x, y) \<in> set (generate A B a b)}
        \<subseteq> set (tl (generate A B a b))"
    by blast
qed

lemma (in hlde) zeroes_ni_non_special_solutions:
  shows "(zeroes m, zeroes n) \<notin> set (non_special_solutions a b)"
proof -
  define All_lex where
    All_lex: "All_lex = generate (Max (set b)) (Max (set a)) a b"
  define z where z: "z = (zeroes m, zeroes n)"
  have "set (non_special_solutions a b) \<subseteq> set (tl (All_lex))"
    by (auto simp: All_lex non_special_solutions_def minimize_def dest: subsetD [OF minimize_wrt_subset])
  moreover have "z \<notin> set (tl (All_lex))"
    using zeroes_ni_generate_tl All_lex z by auto
  ultimately show ?thesis
    using z by blast
qed


subsubsection \<open>Correctness: \<open>solve\<close> generates only minimal solutions.\<close>

lemma (in hlde) solve_subset_Minimal_Solutions:
  shows "set (solve a b) \<subseteq> Minimal_Solutions"
proof (rule subrelI)
  let ?a = "Max (set a)" and ?b = "Max (set b)"
  fix x y
  assume ass: "(x, y) \<in> set (solve a b)"
  then consider "(x, y) \<in> set (special_solutions a b)" | "(x, y) \<in> set (non_special_solutions a b)"
    unfolding solve_def and set_append by blast
  then show "(x, y) \<in> Minimal_Solutions"
  proof (cases)
    case 1
    then have "(x, y) \<in> Special_Solutions"
      unfolding special_solutions .
    then show ?thesis
      by (simp add: Special_Solutions_in_Minimal_Solutions)
  next
    let ?xs = "[(x, y)\<leftarrow>tl (generate ?b ?a a b).
      static_bounds a b x y \<and> a \<bullet> x = b \<bullet> y \<and> boundr x y (*\<and> cond_B x \<and> cond_D x y*) \<and>
      subprodl x y \<and>
      subprodr y]"
    case 2
    then have conds: "\<forall>e\<in>set x. e \<le> Max (set b)" "boundr x y" (*"cond_B x" "cond_D x y"*)
      "subprodl x y" "subprodr y"
      and xs: "(x, y) \<in> set (minimize ?xs)"
      by (auto simp: non_special_solutions_def minimize_def set_generate less_eq_def cond_A_def
          dest!: minimize_wrt_subset [THEN subsetD] in_tl_generate)
        (metis in_set_conv_nth)
    have sol: "(x, y) \<in> Solutions"
      using ass by (auto simp: solve_def Special_Solutions_in_Solutions in_non_special_solutions)
    then have len: "length x = m" "length y = n" by (auto simp: Solutions_def)
    have "nonzero x"
      using sol Solutions_snd_not_0 [of y x]
      by (metis "2" eq_0_iff len nonzero_Solutions_iff nonzero_iff zeroes_ni_non_special_solutions)
    moreover have "\<not> (\<exists>(u, v) \<in> Minimal_Solutions. u @ v <\<^sub>v x @ y)"
    proof
      let ?P = "\<lambda>(x, y) (u, v). \<not> x @ y <\<^sub>v u @ v"
      let ?Q = "(\<lambda>(x, y). static_bounds a b x y \<and> a \<bullet> x = b \<bullet> y \<and> boundr x y (*\<and> cond_B x \<and> cond_D x y*) \<and>
        subprodl x y \<and>
        subprodr y)"
      note sorted = sorted_wrt_tl [OF _ sorted_wrt_generate, simplified, THEN sorted_wrt_filter,
          of ?Q ?b ?a a b]
      note * = in_minimize_wrt_False [OF _ sorted, of "(x, y)" ?P, OF _ xs [unfolded minimize_def]]

      assume "\<exists>(u, v)\<in>Minimal_Solutions. u @ v <\<^sub>v x @ y"
      then obtain u and v where
        uv: "(u, v) \<in> Minimal_Solutions" and less: "u @ v <\<^sub>v x @ y" by blast
      then have le: "u \<le>\<^sub>v x" "v \<le>\<^sub>v y" and sol': "a \<bullet> u = b \<bullet> v"
        and nonzero: "nonzero u"
        using sol by (auto simp: Minimal_Solutions_def Solutions_def elim!: less_append_cases)
      (*with le_imp_conds [OF le conds(2-)]*)
      with le_imp_conds(2,4,5) [OF le] and conds(2-)
      have conds': "\<forall>e\<in>set u. e \<le> Max (set b)" "boundr u v" (*"cond_B u" "cond_D u v"*)
        "subprodl u v" "subprodr v"
        using conds(1,3,4) by (auto simp: len less_eq_def) (metis in_set_conv_nth le_trans len(1))
      moreover have "static_bounds a b u v"
        using max_coeff_bound [OF uv] and Minimal_Solutions_length [OF uv]
        by (auto simp: static_bounds_def maxne0_impl)
      moreover have "x \<le>\<^sub>v replicate m ?b"
        using xs set_generate [of "Max (set b)" "Max (set a)" a b]
          cond_A_def conds(1) le_replicateI len by metis
      moreover have "y \<le>\<^sub>v replicate n ?a"
        using xs minimize_wrt_subset set_generate
      proof -
        have "\<And>s. set (minimize s) \<subseteq> set s"
          by (simp add: minimize_def minimize_wrt_subset)
        then show ?thesis
          using in_tl_generate set_generate xs by fastforce
      qed
      ultimately have "(u, v) \<in> set ?xs"
        using sol' set_generate [of ?b ?a a b] uv [THEN Minimal_Solutions_imp_Solutions] and nonzero
        by (simp add: generate_tl) (metis in_set_replicate le order_vec.dual_order.trans nonzero_iff)
      from * [OF _ _ _ this] and less show False
        using less_imp_rlex and rlex_not_sym by force
    qed
    ultimately show ?thesis by (simp add: Minimal_SolutionsI' sol)
  qed
qed


subsubsection \<open>Completeness: every minimal solution is generated by \<open>solve\<close>\<close>

lemma (in hlde) Minimal_Solutions_subset_solve:
  shows "Minimal_Solutions \<subseteq> set (solve a b)"
proof (rule subrelI)
  fix x y
  assume min: "(x, y) \<in> Minimal_Solutions"
  then have sol: "a \<bullet> x = b \<bullet> y" "length x = m" "length y = n"
    and [dest]: "x = zeroes m \<Longrightarrow> y = zeroes n \<Longrightarrow> False"
    by (auto simp: Minimal_Solutions_def Solutions_def nonzero_iff)
  consider (special) "(x, y) \<in> Special_Solutions"
    | (not_special) "(x, y) \<notin> Special_Solutions" by blast
  then show "(x, y) \<in> set (solve a b)"
  proof (cases)
    case special
    then show ?thesis
      by (simp add: no0 solve_def)
  next
    define all where "all = tl (generate (Max (set b)) (Max (set a)) a b)"
    have *: "\<forall>(u, v) \<in> set (filter (check a b) all). \<not> u @ v <\<^sub>v x @ y"
      using min and no0
      by (auto simp: all_def generate_tl set_generate neq_0_iff' nonzero_iff
               dest!: Minimal_Solutions_min)

    case not_special
    from conds [OF min] and not_special
    have "(x, y) \<in> set (filter (check a b) all)"
      using max_coeff_bound [OF min] and maxne0_le_Max
        and Minimal_Solutions_length [OF min]
      apply (auto simp: sol all_def generate_tl set_generate cond_A_def less_eq_def static_bounds_def maxne0_impl)
       apply (metis le_trans nth_mem sol(2))
       by (metis le_trans nth_mem sol(3))
    from in_minimize_wrtI [OF this, of "\<lambda>(x, y) (u, v). \<not> x @ y <\<^sub>v u @ v"] *
    have "(x, y) \<in> set (non_special_solutions a b)"
      by (auto simp: non_special_solutions_def minimize_def all_def)
    then show ?thesis
      by (simp add: solve_def)
  qed
qed

text \<open>the main correctness and completeness result of our algorithm\<close>
lemma (in hlde) solve [simp]:
  shows "set (solve a b) = Minimal_Solutions"
  using solve_subset_Minimal_Solutions and Minimal_Solutions_subset_solve by blast


section \<open>Making the Algorithm More Efficient\<close>

locale bounded_lexs =
  fixes C :: "nat list \<Rightarrow> nat \<Rightarrow> bool"
    and B :: nat
  assumes bound: "\<And>x xs s. x > B \<Longrightarrow> C (x # xs) s = False"
    and cond_antimono: "\<And>x x' xs s s'. C (x # xs) s \<Longrightarrow> x' \<le> x \<Longrightarrow> s' \<le> s \<Longrightarrow> C (x' # xs) s'"
begin

function incs :: "nat \<Rightarrow> nat \<Rightarrow> (nat list \<times> nat) \<Rightarrow> (nat list \<times> nat) list"
  where
    "incs a x (xs, s) =
      (let t = s + a * x in
      if C (x # xs) t then (x # xs, t) # incs a (Suc x) (xs, s) else [])"
  by (auto)
termination
  by (relation "measure (\<lambda>(a, x, xs, s). B + 1 - x)", rule wf_measure, case_tac "x > B")
    (use bound in auto)
declare incs.simps [simp del]

lemma in_incs:
  assumes "(ys, t) \<in> set (incs a x (xs, s))"
  shows "length ys = length xs + 1 \<and> t = s + hd ys * a \<and> tl ys = xs \<and> C ys t"
  using assms
  by (induct a x "(xs, s)" arbitrary: ys t rule: incs.induct)
    (subst (asm) (2) incs.simps, auto simp: Let_def)

lemma incs_Nil [simp]: "x > B \<Longrightarrow> incs a x (xs, s) = []"
  apply (induct a x "(xs, s)" rule: incs.induct)
  apply (subst incs.simps)
  apply (insert bound, auto simp: Let_def)
  done

lemma incs_filter:
  assumes "x \<le> B"
  shows "incs a x = (\<lambda>(xs, s). filter (cond_cons C) (map (\<lambda>x. (x # xs, s + a * x)) [x ..< B + 1]))"
proof
  fix xss
  show "incs a x xss = (\<lambda>(xs, s). filter (cond_cons C) (map (\<lambda>x. (x # xs, s + a * x)) [x ..< B + 1])) xss"
    using assms
  proof (induct a x xss rule: incs.induct)
    case (1 a x xs s)
    then show ?case
      apply (subst incs.simps)
      apply (cases "x = B")
       apply (auto simp: filter_empty_conv Let_def cond_cons_def upt_conv_Cons intro: cond_antimono)
      done
  qed
qed

fun lexs :: "nat list \<Rightarrow> (nat list \<times> nat) list"
  where
    "lexs [] = [([], 0)]"
  | "lexs (a # as) = concat (map (incs a 0) (lexs as))"

lemma lexs_len:
  assumes "(ys, s) \<in> set (lexs as)"
  shows "length ys = length as"
  using assms
proof (induct as arbitrary: ys s)
  case (Cons a as)
  have "\<exists>(la,t) \<in> set (lexs as). (ys, s) \<in> set (incs a 0 (la,t))"
    using Cons.prems(1) by auto
  moreover obtain  la t where "(la,t) \<in> set (lexs as)"
    using calculation by auto
  moreover have "length ys = length la + 1"
    using calculation
    by (metis (no_types, lifting) Cons.hyps case_prodE in_incs)
  moreover have "length la = length as"
    using calculation
    using Cons.hyps Cons.prems by fastforce
  ultimately show ?case by simp
qed (auto)

lemma in_lexs:
  assumes "(xs, s) \<in> set (lexs as)"
  shows "length xs = length as \<and> s = as \<bullet> xs"
  using assms
  apply (induct as arbitrary: xs s)
   apply (auto simp: in_incs)
  apply (case_tac xs)
   apply (auto dest: in_incs)
  done

lemma lexs_filter:
  "lexs as = filter (suffs C as) (alls B as)"
proof (induct as)
next
  case (Cons a as)
  have "filter (suffs C (a # as)) (alls B (a # as)) =
    filter (\<lambda>(xs, s). cond_cons C (xs, s) \<and> suffs C as (tl xs, as \<bullet> tl xs)) (alls B (a # as))"
    by (intro filter_cong [OF refl])
      (auto dest: in_alls simp: suffs.simps all_Suc_le_conv ac_simps split: list.splits)
  also have "\<dots> =
    concat (map (\<lambda>(xs, s). filter (cond_cons C) (map (\<lambda>x. (x # xs, s + a * x)) [0..<B + 1]))
      (filter (suffs C as) (alls B as)))"
    unfolding alls.simps
    unfolding filter_concat
    unfolding map_map
    by (subst concat_map_filter_filter [symmetric, where Q = "suffs C as"])
      (auto intro!: arg_cong [of _ _ concat] filter_cong dest!: in_alls)
  finally have *: "filter (suffs C (a # as)) (alls B (a # as)) =
    concat (map (\<lambda>(xs, s).
      filter (cond_cons C) (map (\<lambda>x. (x # xs, s + a * x)) [0..<B + 1])) (filter (suffs C as) (alls B as)))" .
  have "lexs (a # as) = filter (suffs C (a # as)) (alls B (a # as))"
    unfolding *
    by (simp add: incs_filter [OF zero_le] Cons)
  then show ?case by simp
qed simp

lemma in_lexs_cond:
  assumes "(xs, s) \<in> set (lexs as)"
  shows "\<forall>j\<le>length xs. drop j xs \<noteq> [] \<longrightarrow> C (drop j xs) (s - take j as \<bullet> take j xs)"
  using assms
  apply (induct as arbitrary: xs s)
   apply auto
  apply (case_tac xs)
   apply auto
  apply (case_tac j)
   apply (auto dest: in_incs)
  done

lemma sorted_lexs:
  "sorted_wrt (op <\<^sub>r\<^sub>l\<^sub>e\<^sub>x) (map fst (lexs xs))"
proof -
  have sort_map: "sorted_wrt (\<lambda>x y. x <\<^sub>r\<^sub>l\<^sub>e\<^sub>x y) (map fst (alls B xs))"
    using sorted_wrt_alls by auto
  then have "sorted_wrt (\<lambda>x y. fst x <\<^sub>r\<^sub>l\<^sub>e\<^sub>x fst y) (alls B xs)"
    using sorted_wrt_map_distr [of "op <\<^sub>r\<^sub>l\<^sub>e\<^sub>x" fst "alls B xs"]
    by (auto)
  then have "sorted_wrt (\<lambda>x y. fst x <\<^sub>r\<^sub>l\<^sub>e\<^sub>x fst y) (filter (suffs C xs) (alls B xs))"
    using sorted_wrt_alls sorted_wrt_filter sorted_wrt_map
    by blast
  then show ?thesis
    using lexs_filter
    by (simp add: case_prod_unfold sorted_wrt_map_mono)
qed

end

locale bounded_lexs2 =
  c2: bounded_lexs C\<^sub>2 B\<^sub>2 for C\<^sub>2 B\<^sub>2 +
  fixes C\<^sub>1 and B\<^sub>1
  assumes cond1: "\<And>b ys. ys \<in> fst ` set (c2.lexs b) \<Longrightarrow> bounded_lexs (C\<^sub>1 b ys) (B\<^sub>1 b)"
begin

definition "lexs2 a b = [(xs, ys). ys \<leftarrow> c2.lexs b, xs \<leftarrow> bounded_lexs.lexs (C\<^sub>1 b (fst ys)) a]"

lemma lexs2_filter_conv:
  "lexs2 a b = [(xs, ys).
    ys \<leftarrow> filter (suffs C\<^sub>2 b) (alls B\<^sub>2 b),
    xs \<leftarrow> filter (suffs (C\<^sub>1 b (fst ys)) a) (alls (B\<^sub>1 b) a)]"
  using bounded_lexs.lexs_filter [OF cond1]
  by (force simp: lexs2_def c2.lexs_filter intro!: arg_cong [of _ _ concat] map_cong)

lemma lexs2_filter:
  "lexs2 a b = [(xs, ys) \<leftarrow> alls2 (B\<^sub>1 b) B\<^sub>2 a b. suffs (C\<^sub>1 b (fst ys)) a xs \<and> suffs C\<^sub>2 b ys]"
  by (auto intro: arg_cong [of _ _ concat]
    simp: lexs2_filter_conv alls2_def filter_concat concat_map_filter filter_map o_def)

lemma tl_lexs2_filter:
  assumes "suffs (C\<^sub>1 b (zeroes (length b))) a (zeroes (length a), 0)"
    and "suffs C\<^sub>2 b (zeroes (length b), 0)"
  shows "tl (lexs2 a b) = [(xs, ys) \<leftarrow> tl (alls2 (B\<^sub>1 b) B\<^sub>2 a b). suffs (C\<^sub>1 b (fst ys)) a xs \<and> suffs C\<^sub>2 b ys]"
  using assms
  apply (auto simp: lexs2_filter)
  apply (subst (1 2) alls2_Cons_tl_conv)
  apply auto
  done

end

context
  fixes a b :: "nat list"
begin

fun cond1
  where
    "cond1 ys [] s \<longleftrightarrow> True"
  | "cond1 ys (x # xs) s \<longleftrightarrow> s \<le> b \<bullet> ys \<and> x \<le> maxne0_impl ys b"

lemma maxx_impl'_conv:
  "i < length a \<Longrightarrow> length y = length b \<Longrightarrow> maxx_impl' a b y i = maxx_impl a b y i"
  by (auto simp: maxx_impl'_def maxx_impl_def Let_def big_d'_def big_d_def)

fun cond2
  where
    "cond2 [] s \<longleftrightarrow> True"
  | "cond2 (y # ys) s \<longleftrightarrow> y \<le> Max (set a) \<and> s \<le> a \<bullet> map (maxx_impl' a b (y # ys)) [0 ..< length a]"

lemma le_imp_big_d'_subset:
  assumes "v \<le>\<^sub>v y"
  shows "set (big_d' a b v i) \<subseteq> set (big_d' a b y i)"
  using assms and le_trans
  by (auto simp: Let_def big_d'_def less_eq_def hlde_ops.dij_def hlde_ops.eij_def)

lemma finite_big_d':
  "finite (set (big_d' a b y i))"
  by (rule finite_subset [of _ "(\<lambda>j. dij a b i (j + length b - length y) - 1) ` {0 ..< length y}"])
    (auto simp: Let_def big_d'_def)

lemma Min_big_d'_le:
  assumes "i < length a"
    and "big_d' a b y i \<noteq> []"
    and "length y \<le> length b"
  shows "Min (set (big_d' a b y i)) \<le> Max (set b)" (is "?m \<le> _")
proof -
  have "?m \<in> set (big_d' a b y i)"
    using assms and finite_big_d' and Min_in by auto
  then obtain j where
    j: "?m = dij a b i (j + length b - length y) - 1" "j < length y" "y ! j \<ge> eij a b i (j + length b - length y)"
    by (auto simp: big_d'_def Let_def split: if_splits)
  then have "j + length b - length y < length b"
    using assms by auto
  moreover
  have "lcm (a ! i) (b ! (j + length b - length y)) div a ! i \<le> b ! (j + length b - length y)" by (rule lcm_div_le')
  ultimately show ?thesis
    using j and assms
    by (auto simp: hlde_ops.dij_def)
      (meson List.finite_set Max_ge diff_le_self le_trans less_le_trans nth_mem)
qed

lemma le_imp_maxx_impl'_ge:
  assumes "v \<le>\<^sub>v y"
    and "i < length a"
  shows "maxx_impl' a b v i \<ge> maxx_impl' a b y i"
  using assms and le_imp_big_d'_subset [OF assms(1), of i]
    and Min_in [OF finite_big_d', of y i]
    and finite_big_d' and Min_le
  by (auto simp: maxx_impl'_def Let_def intro!: Min_big_d'_le [of i y])
    (fastforce simp: big_d'_def intro: leI)

end

global_interpretation c12: bounded_lexs2 "(cond2 a b)" "Max (set a)" "cond1" "\<lambda>b. Max (set b)"
  defines c2_lexs = c12.c2.lexs and c2_incs = c12.c2.incs
    and c12_lexs2 = c12.lexs2
proof -
  { fix x xs s assume "Max (set a) < x"
    then have "cond2 a b (x # xs) s = False" by (auto) }
  note 1 = this

  { fix x x' xs s s' assume "cond2 a b (x # xs) s" and "x' \<le> x" and "s' \<le> s"
    moreover have "map (maxx_impl' a b (x # xs)) [0..<length a] \<le>\<^sub>v map (maxx_impl' a b (x' # xs)) [0..<length a]"
      using le_imp_maxx_impl'_ge [of "x' # xs" "x # xs"] and \<open>x' \<le> x\<close>
      by (auto simp: le_Cons less_eq_def all_Suc_conv)
    ultimately have "cond2 a b (x' # xs) s'"
      by (auto simp: le_Cons) (metis dotprod_le_right le_trans length_map map_nth) }
  note 2 = this

  interpret c2: bounded_lexs "cond2 a b" "Max (set a)" by (standard) fact+

  { fix b ys x xs s assume "ys \<in> fst ` set (c2.lexs b)" and "Max (set b) < x"
  then have "cond1 b ys (x # xs) s = False"
    by (auto dest!: c2.in_lexs) (metis leD less_le_trans maxne0_impl maxne0_le_Max) }
  note 3 = this

  { fix b ys x x' xs s s' assume "ys \<in> fst ` set (c2.lexs b)" and "cond1 b ys (x # xs) s"
      and "x' \<le> x" and "s' \<le> s"
    then have "cond1 b ys (x' # xs) s'" by auto }
  note 4 = this

  show "bounded_lexs2 (cond2 a b) (Max (set a)) cond1 (\<lambda>b. Max (set b))"
    using 1 and 2 and 3 and 4 by (unfold_locales) metis+
qed

definition "post_cond a b = (\<lambda>(x, y). static_bounds a b x y \<and> a \<bullet> x = b \<bullet> y \<and> boundr_impl a b x y)"

definition "fast_filter a b =
  filter (post_cond a b) (map (\<lambda>(x, y). (fst x, fst y)) (tl (c12_lexs2 a b a b)))"

lemma cond1_cond2_zeroes:
  shows "suffs (cond1 b (zeroes (length b))) a (zeroes (length a), 0)"
    and "suffs (cond2 a b) b (zeroes (length b), 0)"
   apply (auto simp: suffs.simps cond_cons_def split: list.splits)
     apply (metis dotprod_0_right length_drop)
    apply (metis Cons_replicate_eq Nat.le0)
   apply (metis Cons_replicate_eq Nat.le0)
  by (metis Nat.le0 dotprod_0_right length_drop)

lemma suffs_cond1I:
  assumes "\<forall>y\<in>set aa. y \<le> maxne0_impl aaa b"
    and "length aa = length a"
    and "a \<bullet> aa = b \<bullet> aaa"
  shows "suffs (cond1 b aaa) a (aa, b \<bullet> aaa)"
  using assms
  apply (auto simp: suffs.simps cond_cons_def split: list.splits)
   apply (metis dotprod_le_drop)
  by (metis in_set_dropD list.set_intros(1))

lemma suffs_cond2_conv:
  assumes "length ys = length b"
  shows "suffs (cond2 a b) b (ys, b \<bullet> ys) \<longleftrightarrow>
    (\<forall>y\<in>set ys. y \<le> Max (set a)) \<and> pdprodr_impl a b ys"
    (is "?L \<longleftrightarrow> ?R")
proof
  assume *: ?L
  then have "\<forall>y\<in>set ys. y \<le> Max (set a)"
    apply (auto simp: suffs.simps cond_cons_def in_set_conv_nth split: list.splits)
    apply (auto simp: hd_drop_conv_nth [symmetric])
    apply (case_tac "drop i ys")
      apply simp_all
    using less_or_eq_imp_le by blast
  moreover
  { fix l assume l: "l \<le> length b"
    have "take l b \<bullet> take l ys \<le> b \<bullet> ys"
      using l and assms by (simp add: dotprod_le_take)
    also have "\<dots> \<le> a \<bullet> map (maxx_impl' a b ys) [0 ..< length a]"
      using * apply (auto simp: suffs.simps cond_cons_def split: list.splits)
      apply (drule_tac x = "0" in spec)
        apply (cases ys)
       apply auto
      done
    also have "\<dots> = a \<bullet> map (maxx_impl a b ys) [0 ..< length a]"
      using maxx_impl'_conv [OF _ assms, of _ a]
      by (metis (mono_tags, lifting) atLeastLessThan_iff map_eq_conv set_upt)
    also have "\<dots> \<le> a \<bullet> map (maxx_impl a b (take l ys)) [0 ..< length a]"
      unfolding maxx_impl using hlde_ops.maxx_le_take [OF eq_imp_le, OF assms, of a]
      by (intro dotprod_le_right) (auto simp: less_eq_def)
    finally have "take l b \<bullet> take l ys \<le> a \<bullet> map (maxx_impl a b (take l ys)) [0 ..< length a]" .
  }
  ultimately show "?R" by (auto simp: pdprodr_impl_def)
next
  assume *: ?R
  then have "\<forall>y\<in>set ys. y \<le> Max (set a)" and "pdprodr_impl a b ys" by auto
  moreover
  { fix i assume i: "i \<le> length b"
    have "drop i b \<bullet> drop i ys \<le> b \<bullet> ys"
      using i and assms by (simp add: dotprod_le_drop)
    also have "\<dots> \<le> a \<bullet> map (maxx_impl a b ys) [0 ..< length a]"
      using * and assms by (auto simp: pdprodr_impl_def)
    also have "\<dots> = a \<bullet> map (maxx_impl' a b ys) [0 ..< length a]"
      using maxx_impl'_conv [OF _ assms, of _ a]
      by (metis (mono_tags, lifting) atLeastLessThan_iff map_eq_conv set_upt)
    also have "\<dots> \<le> a \<bullet> map (maxx_impl' a b (drop i ys)) [0 ..< length a]"
      using hlde_ops.maxx'_le_drop [OF eq_imp_le, OF assms, of a]
      by (intro dotprod_le_right) (auto simp: less_eq_def maxx_impl' i assms)
    finally have "drop i b \<bullet> drop i ys \<le> a \<bullet> map (maxx_impl' a b (drop i ys)) [0 ..< length a]" .
  }
  ultimately show "?L"
    using assms
    apply (auto simp: suffs.simps cond_cons_def split: list.splits)
     apply (metis in_set_dropD list.set_intros(1))
    apply force
    done
qed

lemma suffs_cond2I:
  assumes "\<forall>y\<in>set aaa. y \<le> Max (set a)"
    and "length aaa = length b"
    and "pdprodr_impl a b aaa"
  shows "suffs (cond2 a b) b (aaa, b \<bullet> aaa)"
  using assms by (subst suffs_cond2_conv) simp_all

lemma check_conv:
  assumes "(x, y) \<in> set (alls2 (Max (set b)) (Max (set a)) a b)"
  shows "check a b (fst x, fst y) \<longleftrightarrow>
    static_bounds a b (fst x) (fst y) \<and> a \<bullet> fst x = b \<bullet> fst y \<and> boundr_impl a b (fst x) (fst y) \<and>
    suffs (cond1 b (fst y)) a x \<and>
    suffs (cond2 a b) b y"
  using assms
  apply (cases x; cases y; auto simp: static_bounds_def check_def dest!: in_alls2 split: list.splits)
     apply (auto intro: suffs_cond1I suffs_cond2I simp: pdprodl_impl_def suffs_cond2_conv)
  by (metis dotprod_le_take)

lemma tune:
  "filter (check a b) (tl (generate (Max (set b)) (Max (set a)) a b)) = fast_filter a b"
  using cond1_cond2_zeroes
  unfolding fast_filter_def
  apply (subst c12.tl_lexs2_filter)
    apply (auto simp: generate_def map_tl [symmetric] filter_map post_cond_def intro!: map_cong)
  apply (auto simp: o_def)
  apply (rule filter_cong)
   apply (auto dest!: list.set_sel(2) [THEN check_conv, OF alls2_ne])
  done

locale bounded_incs =
  fixes cond :: "nat list \<Rightarrow> nat \<Rightarrow> bool"
    and B :: nat
  assumes bound: "\<And>x xs s. x > B \<Longrightarrow> cond (x # xs) s = False"
begin

function incs :: "nat \<Rightarrow> nat \<Rightarrow> (nat list \<times> nat) \<Rightarrow> (nat list \<times> nat) list"
  where
    "incs a x (xs, s) =
      (let t = s + a * x in
      if cond (x # xs) t then (x # xs, t) # incs a (Suc x) (xs, s) else [])"
  by (auto)
termination
  by (relation "measure (\<lambda>(a, x, xs, s). B + 1 - x)", rule wf_measure, case_tac "x > B")
    (use bound in auto)
declare incs.simps [simp del]

lemma in_incs:
  assumes "(ys, t) \<in> set (incs a x (xs, s))"
  shows "length ys = length xs + 1 \<and> t = s + hd ys * a \<and> tl ys = xs \<and> cond ys t"
  using assms
  by (induct a x "(xs, s)" arbitrary: ys t rule: incs.induct)
    (subst (asm) (2) incs.simps, auto simp: Let_def)

lemma incs_Nil [simp]: "x > B \<Longrightarrow> incs a x (xs, s) = []"
  apply (induct a x "(xs, s)" rule: incs.induct)
  apply (subst incs.simps)
  apply (insert bound, auto simp: Let_def)
  done

end

global_interpretation incs1:
  bounded_incs "(cond1 b ys)" "(Max (set b))"
  for b ys :: "nat list"
  defines c1_incs = incs1.incs
proof
  fix x xs s
  assume "Max (set b) < x"
  then show "cond1 b ys (x # xs) s = False"
    using maxne0_impl_le [of ys b] by auto
qed

fun c1_lexs
  where
    "c1_lexs b ys [] = [([], 0)]"
  | "c1_lexs b ys (a # as) = concat (map (c1_incs b ys a 0) (c1_lexs b ys as))"

definition "lexs2 a b = [(xs, ys). ys \<leftarrow> c2_lexs a b b, xs \<leftarrow> c1_lexs b (fst ys) a]"

lemma c1_lexs_conv:
  assumes "(ys, s) \<in> set (c2_lexs a b b)"
  shows "c1_lexs b ys a = bounded_lexs.lexs (cond1 b ys) a"
proof -
  interpret c1: bounded_lexs "(cond1 b ys)" "Max (set b)"
    by (unfold_locales) (auto, meson leD less_le_trans maxne0_impl_le)
  have eq: "c1_incs b ys a1 0 (a, ba) = c1.incs a1 0 (a, ba)" if "(a, ba) \<in> set (c1.lexs a2)"
    for a a1 a2 ba
    using that
    apply (induct rule: c1.incs.induct)
    apply (auto dest!: c1.in_lexs)
    apply (subst incs1.incs.simps)
    apply (subst c1.incs.simps)
    by (auto simp: Let_def)
  show ?thesis
    by (induct a) (auto intro!: arg_cong [of _ _ concat] dest: eq)
qed


subsection \<open>Code Generation\<close>

lemma solve_efficient [code]:
  "solve a b = special_solutions a b @ minimize (fast_filter a b)"
  by (auto simp: solve_def non_special_solutions_def tune)

lemma c12_lexs2_code [code_unfold]:
  "c12_lexs2 a b a b = lexs2 a b"
  by (auto simp: lexs2_def c12.lexs2_def c1_lexs_conv intro!: arg_cong [of _ _ concat])

end
