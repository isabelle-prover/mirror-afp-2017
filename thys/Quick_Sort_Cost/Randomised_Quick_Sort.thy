(*
  File:     Randomised_Quick_Sort.thy
  Author:   Manuel Eberl <eberlm@in.tum.de>

  Definition and cost analysis of randomised QuickSort (i.e. pivot chosen uniformly at random).
*)
section \<open>Randomised QuickSort\<close>
theory Randomised_Quick_Sort
  imports 
    Probability 
    Landau_Symbols.Landau_Symbols
    Comparison_Sort_Lower_Bound.Linorder_Relations
begin

subsection \<open>Deletion by index\<close>  

text \<open>
  The following function deletes the $n$-th element of a list.
\<close>

fun delete_index :: "nat \<Rightarrow> 'a list \<Rightarrow> 'a list" where
  "delete_index _ [] = []"
| "delete_index 0 (x # xs) = xs"
| "delete_index (Suc n) (x # xs) = x # delete_index n xs"

lemma delete_index_altdef: "delete_index n xs = take n xs @ drop (Suc n) xs"
  by (induction n xs rule: delete_index.induct) simp_all

lemma delete_index_ge_length: "n \<ge> length xs \<Longrightarrow> delete_index n xs = xs"
  by (simp add: delete_index_altdef)

lemma length_delete_index [simp]: "n < length xs \<Longrightarrow> length (delete_index n xs) = length xs - 1"
  by (simp add: delete_index_altdef)

lemma delete_index_Cons: 
  "delete_index n (x # xs) = (if n = 0 then xs else x # delete_index (n - 1) xs)"
  by (cases n) simp_all
    
lemma insert_set_delete_index:
  "n < length xs \<Longrightarrow> insert (xs ! n) (set (delete_index n xs)) = set xs"
  by (induction n xs rule: delete_index.induct) auto

lemma add_mset_delete_index: 
  "i < length xs \<Longrightarrow> add_mset (xs ! i) (mset (delete_index i xs)) = mset xs"
  by (induction i xs rule: delete_index.induct) simp_all
    
lemma nth_delete_index: 
  "i < length xs \<Longrightarrow> n < length xs \<Longrightarrow> 
     delete_index n xs ! i = (if i < n then xs ! i else xs ! Suc i)"
  by (auto simp: delete_index_altdef nth_append min_def)

lemma set_delete_index_distinct:
  assumes "distinct xs" "n < length xs"
  shows   "set (delete_index n xs) = set xs - {xs ! n}"
  using assms by (induction n xs rule: delete_index.induct) fastforce+
    
lemma distinct_delete_index [simp, intro]: 
  assumes "distinct xs"
  shows   "distinct (delete_index n xs)"
proof (cases "n < length xs")
  case True
  with assms show ?thesis
    by (induction n xs rule: delete_index.induct) (auto simp: set_delete_index_distinct)
qed (simp_all add: delete_index_ge_length assms)

lemma mset_delete_index [simp]: 
  "i < length xs \<Longrightarrow> mset (delete_index i xs) = mset xs - {# xs!i #}"
  by (induction i xs rule: delete_index.induct) simp_all


subsection \<open>Definition of QuickSort\<close>

text \<open>
  The following is a functional randomised version of QuickSort that also records the number 
  of comparisons that were made. The randomisation is in the selection of the pivot element: 
  In each step, the next pivot is chosen uniformly at random from all remaining list elements.

  The function takes the ordering relation to use as a first argument in the form of a set of 
  pairs.
\<close>  

function rquicksort :: "('a \<times> 'a) set \<Rightarrow> 'a list \<Rightarrow> ('a list \<times> nat) pmf" where
  "rquicksort R xs = 
     (if xs = [] then 
        return_pmf ([], 0)
      else
        do {
          i \<leftarrow> pmf_of_set {..<length xs};
          let x = xs ! i;
          case partition (\<lambda>y. (y,x) \<in> R) (delete_index i xs) of
            (ls, rs) \<Rightarrow> do {
              (ls, n1) \<leftarrow> rquicksort R ls;
              (rs, n2) \<leftarrow> rquicksort R rs;
              return_pmf (ls @ [x] @ rs, length xs - 1 + n1 + n2)
            }
        })"
  by auto
termination proof (relation "Wellfounded.measure (length \<circ> snd)", goal_cases)
  show "wf (Wellfounded.measure (length \<circ> snd))" by simp
qed (subst (asm) set_pmf_of_set; force intro!: le_less_trans[OF length_filter_le])+

declare rquicksort.simps [simp del]

lemma rquicksort_Nil [simp]: "rquicksort R [] = return_pmf ([], 0)"
  by (simp add: rquicksort.simps)

 
subsection \<open>Correctness proof\<close>

lemma set_pmf_of_set_lessThan_length [simp]:
  "xs \<noteq> [] \<Longrightarrow> set_pmf (pmf_of_set {..<length xs}) = {..<length xs}"
  by (subst set_pmf_of_set) auto
    
text \<open>
  We can now prove that any list that can be returned by QuickSort is sorted w.\,r.\,t.\ the 
  given relation. (as long as that relation is reflexive, transitive, and total)
\<close>

theorem rquicksort_correct:
  assumes "trans R" and "total_on (set xs) R" and "\<forall>x\<in>set xs. (x,x) \<in> R"
  assumes "(ys, n) \<in> set_pmf (rquicksort R xs)"
  shows   "sorted_wrt R ys \<and> mset ys = mset xs"
  using assms(2-)
proof (induction xs arbitrary: ys n rule: length_induct)
  case (1 xs)
  have IH: "sorted_wrt R zs" "mset zs = mset ys" 
    if "(zs, n) \<in> set_pmf (rquicksort R ys)" "length ys < length xs" "set ys \<subseteq> set xs" for zs ys n
    using that "1.IH" total_on_subset[OF "1.prems"(1) that(3)] "1.prems"(2) by blast+
  show ?case
  proof (cases "xs = []")
    case False
    with "1.prems" obtain ls rs n1 n2 i where *:
       "i < length xs" "(ls, n1) \<in> set_pmf (rquicksort R [y\<leftarrow>delete_index i xs. (y, xs ! i) \<in> R])"
       "(rs, n2) \<in> set_pmf (rquicksort R [y\<leftarrow>delete_index i xs. (y, xs ! i) \<notin> R])"
       "ys = ls @ [xs ! i] @ rs"
      by (subst (asm) rquicksort.simps[of _ xs]) (auto simp: Let_def o_def)
    note ys = \<open>ys = ls @ [xs ! i] @ rs\<close>
    define ls' where "ls' = [y\<leftarrow>delete_index i xs. (y, xs ! i) \<in> R]"
    define rs' where "rs' = [y\<leftarrow>delete_index i xs. (y, xs ! i) \<notin> R]"
    from \<open>i < length xs\<close> have less: "length ls' < length xs" "length rs' < length xs"
      unfolding ls'_def rs'_def by (intro le_less_trans[OF length_filter_le]; force)+
    have ls: "(ls, n1) \<in> set_pmf (rquicksort R ls')" and rs: "(rs, n2) \<in> set_pmf (rquicksort R rs')"
      using * unfolding ls'_def rs'_def by blast+
    have subset: "set ls' \<subseteq> set xs" "set rs' \<subseteq> set xs"
      using insert_set_delete_index[of i xs] \<open>i < length xs\<close>
      by (auto simp: ls'_def rs'_def)
    have sorted: "sorted_wrt R ls" "sorted_wrt R rs" 
     and mset: "mset ls = mset ls'" "mset rs = mset rs'"
      by (rule IH[of ls n1 ls'] IH[of rs n2 rs'] less ls rs subset)+
        
    have ls_le: "(x, xs ! i) \<in> R" if "x \<in> set ls" for x
    proof -
      from that have "x \<in># mset ls" by simp
      also note mset(1)
      finally show ?thesis by (simp add: ls'_def)
    qed
    have rs_ge: "(x, xs ! i) \<notin> R" "(xs ! i, x) \<in> R" if "x \<in> set rs" for x
    proof -
      from that have "x \<in># mset rs" by simp
      also note mset(2)
      finally have x: "x \<in> set rs'" by simp
      thus "(x, xs ! i) \<notin> R" by (simp_all add: rs'_def)
      from x and subset and \<open>i < length xs\<close> have "x \<in> set xs" "xs ! i \<in> set xs" by auto
      with "1.prems" and \<open>(x, xs ! i) \<notin> R\<close> show "(xs ! i, x) \<in> R"
        unfolding total_on_def by (cases "xs ! i = x") auto
    qed
    
    have "sorted_wrt R ys" unfolding ys
      by (intro sorted_wrt_append \<open>trans R\<close> sorted_wrt_singleton sorted)
         (auto intro: rs_ge ls_le transD[OF \<open>trans R\<close>, of _ "xs!i"])
    moreover have "mset ys = mset xs" unfolding ys using \<open>i < length xs\<close>
      by (simp add: mset ls'_def rs'_def add_mset_delete_index)
    ultimately show ?thesis ..
  qed (insert "1.prems", simp_all)
qed
  

subsection \<open>Cost analysis\<close>

text \<open>
  The following distribution describes the number of comparisons made by randomised 
  QuickSort in terms of the list length. (This is only valid if all list elements are distinct)

  A succinct explanation of this cost analysis is given by Jacek Cicho\'{n}~\cite{cichon}.
\<close>
fun rqs_cost :: "nat \<Rightarrow> nat pmf" where
  "rqs_cost 0 = return_pmf 0"
| "rqs_cost (Suc n) = 
     do {i \<leftarrow> pmf_of_set {..n}; a \<leftarrow> rqs_cost i; b \<leftarrow> rqs_cost (n - i); return_pmf (n + a + b)}"
     
lemma finite_set_pmf_rqs_cost [intro!]: "finite (set_pmf (rqs_cost n))"
  by (induction n rule: rqs_cost.induct) simp_all


text \<open>
  We connect the @{const rqs_cost} function to the @{const rquicksort} function by showing that
  projecting out the number of comparisons from a run of @{const rquicksort} on a list with distinct
  elements yields the same distribution as @{const rqs_cost} for the length of that list.
\<close>
theorem snd_rquicksort:
  assumes "linorder_on A R" and "set xs \<subseteq> A" and "distinct xs"
  shows   "map_pmf snd (rquicksort R xs) = rqs_cost (length xs)"
  using assms(2-)
proof (induction xs rule: length_induct)
  case (1 xs)
  have IH: "map_pmf snd (rquicksort R ys) = rqs_cost (length ys)"
    if "length ys < length xs" "mset ys \<subseteq># mset xs" for ys
  proof -
    from set_mset_mono[OF that(2)] have "set ys \<subseteq> set xs" by simp
    also note \<open>set xs \<subseteq> A\<close>
    finally have "set ys \<subseteq> A" .
    moreover from \<open>distinct xs\<close> and that(2) have "distinct ys" 
      by (rule distinct_mset_mono)
    ultimately show ?thesis using that and "1.IH" by blast
  qed
  define n where "n = length xs"
  define cnt where "cnt = (\<lambda>i. length [y\<leftarrow>delete_index i xs. (y, xs ! i) \<in> R])"
  have cnt_altdef: "cnt i = linorder_rank R (set xs) (xs ! i)" if i: "i < n" for i
  proof -
    have "cnt i = length [y\<leftarrow>delete_index i xs. (y, xs ! i) \<in> R]" by (simp add: cnt_def)
    also have "\<dots> = card (set [y\<leftarrow>delete_index i xs. (y, xs ! i) \<in> R])"
      by (intro distinct_card [symmetric] distinct_filter distinct_delete_index "1.prems")
    also have "set [y\<leftarrow>delete_index i xs. (y, xs ! i) \<in> R] = 
                      {x \<in> set xs-{xs!i}. (x, xs ! i) \<in> R}"
      using "1.prems" and i by (simp add: set_delete_index_distinct n_def)
    also have "card \<dots> = linorder_rank R (set xs) (xs ! i)" by (simp add: linorder_rank_def)
    finally show ?thesis .
  qed
  
  from "1.prems" have "bij_betw (op ! xs) {..<n} (set xs)"
    by (intro bij_betw_byWitness[where f' = "index xs"]) (auto simp: n_def index_nth_id)
  moreover have "bij_betw (linorder_rank R (set xs)) (set xs) {..<card (set xs)}"
    using assms(1) by (rule bij_betw_linorder_rank) (insert "1.prems", auto)
  ultimately have "bij_betw (linorder_rank R (set xs) \<circ> (\<lambda>i. xs ! i)) {..<n} {..<card (set xs)}"
    by (rule bij_betw_trans)
  hence bij: "bij_betw (\<lambda>i. linorder_rank R (set xs) (xs ! i)) {..<n} {..<n}"
    using "1.prems" by (simp add: n_def o_def distinct_card)

  show ?case
  proof (cases "xs = []")
    case False
    hence "n > 0" by (simp add: n_def)
    hence [simp]: "n \<noteq> 0" by (intro notI) auto
    from False have "map_pmf snd (rquicksort R xs) = 
             pmf_of_set {..<length xs} \<bind> 
               (\<lambda>i. map_pmf (\<lambda>z. length xs - 1 + fst z + snd z)
                  (pair_pmf (map_pmf snd (rquicksort R [y\<leftarrow>delete_index i xs. (y, xs ! i) \<in> R]))
                            (map_pmf snd (rquicksort R [y\<leftarrow>delete_index i xs. (y, xs ! i) \<notin> R]))))"
      by (subst rquicksort.simps)
         (simp add: map_bind_pmf bind_map_pmf Let_def case_prod_unfold o_def pair_pmf_def)
    also have "\<dots> = pmf_of_set {..<length xs} \<bind> 
                      (\<lambda>i. map_pmf (\<lambda>z. n - 1 + fst z + snd z)
                         (pair_pmf (rqs_cost (cnt i)) (rqs_cost (n - 1 - cnt i))))"
    proof (intro bind_pmf_cong refl, goal_cases)
      case (1 i)
      with \<open>xs \<noteq> []\<close> have i: "i < length xs" by auto
      from i have "map_pmf snd (rquicksort R [y\<leftarrow>delete_index i xs. (y, xs ! i) \<notin> R]) = 
                              rqs_cost (length [y\<leftarrow>delete_index i xs. (y, xs ! i) \<notin> R])"
        by (intro IH) 
           (auto intro!: le_less_trans[OF length_filter_le] simp: mset_filter 
                 intro: subset_mset.order.trans multiset_filter_subset diff_subset_eq_self)
      also have "length [y\<leftarrow>delete_index i xs. (y, xs ! i) \<notin> R] = n - 1 - cnt i"
        unfolding n_def cnt_def 
        using sum_length_filter_compl[of "\<lambda>y. (y, xs ! i) \<in> R" "delete_index i xs"] i by simp
      finally have "map_pmf snd (rquicksort R [y\<leftarrow>delete_index i xs. (y, xs ! i) \<notin> R]) = 
                      rqs_cost (n - 1 - cnt i)" .
      moreover have "map_pmf snd (rquicksort R [y\<leftarrow>delete_index i xs. (y, xs ! i) \<in> R]) = 
                       rqs_cost (cnt i)" unfolding cnt_def using i
        by (intro IH) 
           (auto intro!: le_less_trans[OF length_filter_le] simp: mset_filter 
                 intro: subset_mset.order.trans multiset_filter_subset diff_subset_eq_self)
      ultimately show ?case by (simp only: n_def)
    qed
    also have "\<dots> = map_pmf cnt (pmf_of_set {..<n}) \<bind> 
          (\<lambda>i. map_pmf (\<lambda>z. n - 1 + fst z + snd z) (pair_pmf (rqs_cost i) (rqs_cost (n - 1 - i))))"
      (is "_ = bind_pmf _ ?f") by (simp add: bind_map_pmf n_def)
    also have "map_pmf cnt (pmf_of_set {..<n}) = 
                 map_pmf (\<lambda>i. linorder_rank R (set xs) (xs ! i)) (pmf_of_set {..<n})"
      using \<open>n > 0\<close> by (intro map_pmf_cong refl, subst (asm) set_pmf_of_set) (auto simp: cnt_altdef)
    also from \<open>n > 0\<close> have "\<dots> = pmf_of_set {..<n}" by (intro map_pmf_of_set_bij_betw bij) auto
    also have "pmf_of_set {..<n} \<bind> ?f = rqs_cost n"
      by (cases n) (simp_all add: lessThan_Suc_atMost bind_map_pmf map_bind_pmf pair_pmf_def)
    finally show ?thesis by (simp add: n_def)
  qed simp_all
qed


subsection \<open>Expected cost\<close>

text \<open>
  It is relatively straightforward to see that the following recursive function 
  (sometimes called the `QuickSort equation') describes the expectation of @{const rqs_cost}, 
  i.e. the expected number of comparisons of QuickSort when run on a list with distinct elements.
\<close>
fun rqs_cost_exp :: "nat \<Rightarrow> real" where
  "rqs_cost_exp 0 = 0"
| "rqs_cost_exp (Suc n) = real n + (\<Sum>i\<le>n. rqs_cost_exp i + rqs_cost_exp (n - i)) / real (Suc n)"

lemmas rqs_cost_exp_0 = rqs_cost_exp.simps(1)
lemmas rqs_cost_exp_Suc [simp del] = rqs_cost_exp.simps(2)
lemma rqs_cost_exp_Suc_0 [simp]: "rqs_cost_exp (Suc 0) = 0" by (simp add: rqs_cost_exp_Suc)
  
text \<open>
  The following theorem shows that @{const rqs_cost_exp} is indeed the expectation of 
  @{const rqs_cost}.
\<close>
theorem expectation_rqs_cost: "measure_pmf.expectation (rqs_cost n) real = rqs_cost_exp n"
proof (induction n rule: rqs_cost.induct)
  case (2 n)
  note IH = "2.IH"
  have "measure_pmf.expectation (rqs_cost (Suc n)) real = 
          (\<Sum>a\<le>n. inverse (real (Suc n)) *
              measure_pmf.expectation (rqs_cost a \<bind> (\<lambda>aa. rqs_cost (n - a) \<bind>
                 (\<lambda>b. return_pmf (n + aa + b)))) real)"
    unfolding rqs_cost.simps by (subst pmf_expectation_bind_pmf_of_set) auto
  also have "\<dots> = (\<Sum>i\<le>n. inverse (real (Suc n)) * (real n + rqs_cost_exp i + rqs_cost_exp (n - i)))"
  proof (intro sum.cong refl, goal_cases)
    case (1 i)
    have "rqs_cost i \<bind> (\<lambda>a. rqs_cost (n - i) \<bind> (\<lambda>b. return_pmf (n + a + b))) = 
            map_pmf (\<lambda>(a,b). n + a + b) (pair_pmf (rqs_cost i) (rqs_cost (n - i)))"
      by (simp add: pair_pmf_def map_bind_pmf)
    also have "measure_pmf.expectation \<dots> real = 
                 measure_pmf.expectation (pair_pmf (rqs_cost i) (rqs_cost (n - i))) 
                   (\<lambda>z. real n + (real (fst z) + real (snd z)))"
      by (subst integral_map_pmf) (simp add: case_prod_unfold add_ac)
    also have "\<dots> = real n + measure_pmf.expectation (pair_pmf (rqs_cost i) (rqs_cost (n - i)))
                      (\<lambda>z. real (fst z) + real (snd z))" (is "_ = _ + ?A")
      by (subst Bochner_Integration.integral_add) (auto intro!: integrable_measure_pmf_finite)
    also have "?A = measure_pmf.expectation (map_pmf fst (pair_pmf (rqs_cost i) (rqs_cost (n - i)))) real +
                    measure_pmf.expectation (map_pmf snd (pair_pmf (rqs_cost i) (rqs_cost (n - i)))) real"
      unfolding integral_map_pmf
      by (subst Bochner_Integration.integral_add) (auto intro!: integrable_measure_pmf_finite)
    also have "\<dots> = measure_pmf.expectation (rqs_cost i) real +
                    measure_pmf.expectation (rqs_cost (n - i)) real"
      unfolding map_fst_pair_pmf map_snd_pair_pmf ..
    also from 1 have "\<dots> = rqs_cost_exp i + rqs_cost_exp (n - i)" by (simp_all add: IH)
    finally show ?case by simp
  qed
  also have "\<dots> = (\<Sum>i\<le>n. inverse (real (Suc n)) * real n) + 
                    (\<Sum>i\<le>n. rqs_cost_exp i + rqs_cost_exp (n - i)) / real (Suc n)"
    by (simp add: sum.distrib field_simps sum_distrib_left sum_distrib_right 
          sum_divide_distrib [symmetric] del: of_nat_Suc)
  also have "(\<Sum>i\<le>n. inverse (real (Suc n)) * real n) = real n" by simp
  also have "\<dots> + (\<Sum>i\<le>n. rqs_cost_exp i + rqs_cost_exp (n - i)) / real (Suc n) = rqs_cost_exp (Suc n)" 
    by (simp add: rqs_cost_exp_Suc)
  finally show ?case .
qed simp_all


text \<open>
  We will now obtain a closed-form solution for @{const rqs_cost_exp}. First of all, we can 
  reindex the right-most sum in the recursion step and obtain:
\<close>
lemma rqs_cost_exp_Suc':
  "rqs_cost_exp (Suc n) = real n + 2 / real (Suc n) * (\<Sum>i\<le>n. rqs_cost_exp i)"
proof -
  have "rqs_cost_exp (Suc n) = real n + (\<Sum>i\<le>n. rqs_cost_exp i + rqs_cost_exp (n - i)) / real (Suc n)"
    by (rule rqs_cost_exp_Suc)
  also have "(\<Sum>i\<le>n. rqs_cost_exp i + rqs_cost_exp (n - i)) = (\<Sum>i\<le>n. rqs_cost_exp i) + (\<Sum>i\<le>n. rqs_cost_exp (n - i))"
    by (simp add: sum.distrib)
  also have "(\<Sum>i\<le>n. rqs_cost_exp (n - i)) = (\<Sum>i\<le>n. rqs_cost_exp i)"
    by (intro sum.reindex_bij_witness[of _ "\<lambda>i. n - i" "\<lambda>i. n - i"]) auto
  also have "\<dots> + \<dots> = 2 * \<dots>" by simp
  also have "\<dots> / real (Suc n) = 2 / real (Suc n) * (\<Sum>i\<le>n. rqs_cost_exp i)" by simp
  finally show ?thesis .
qed

text \<open>
  Next, we can apply some standard techniques to transform this equation into a simple
  linear recurrence, which we can then solve easily in terms of harmonic numbers:
\<close>
theorem rqs_cost_exp_eq [code]: "rqs_cost_exp n = 2 * real (n + 1) * harm n - 4 * real n"
proof -
  define F where "F = (\<lambda>n. rqs_cost_exp n / (real n + 1))"
  have [simp]: "F 0 = 0" "F (Suc 0) = 0" by (simp_all add: F_def)
  have F_Suc: "F (Suc m) = F m + real (2*m) / (real ((m+1)*(m+2)))" if "m > 0" for m
  proof (cases m)
    case (Suc n)
    have A: "rqs_cost_exp (Suc (Suc n)) * real (Suc (Suc n)) = 
            real ((n+1)*(n+2)) + 2 * (\<Sum>i\<le>n. rqs_cost_exp i) + 2 * rqs_cost_exp (Suc n)"
      by (subst rqs_cost_exp_Suc') (simp_all add: field_simps)
    have B: "rqs_cost_exp (Suc n) * real (Suc n) = real (n*(n+1)) + 2 * (\<Sum>i\<le>n. rqs_cost_exp i)"
      by (subst rqs_cost_exp_Suc') (simp_all add: field_simps)
    have "rqs_cost_exp (Suc (Suc n)) * real (Suc (Suc n)) - rqs_cost_exp (Suc n) * real (Suc n) =
            real ((n+1)*(n+2)) - real (n*(n+1)) + 2 * rqs_cost_exp (Suc n)"
      by (subst A, subst B) simp_all
    also have "real ((n+1)*(n+2)) - real (n*(n+1)) = real (2*(n+1))" by simp
    finally have "rqs_cost_exp (Suc (Suc n)) * real (n+2) = rqs_cost_exp (Suc n) * real (n+3) + real (2*(n+1))"
      by (simp add: algebra_simps)
    hence "rqs_cost_exp (Suc (Suc n)) / real (n+3) = 
             rqs_cost_exp (Suc n) / real (n+2) + real (2*(n+1)) / (real (n+2)*real (n+3))"
      by (simp add: divide_simps del: of_nat_Suc of_nat_add)
    thus ?thesis by (simp add: F_def algebra_simps Suc)
  qed simp_all
  
  have F_eq: "F n = 2 * (\<Sum>k=1..n. real (k - 1) / real (k * (k + 1)))" for n
  proof (cases "n \<ge> 1")
    case True
    thus ?thesis by (induction n rule: dec_induct) (simp_all add: F_Suc algebra_simps)
  qed (simp_all add: not_le)
  
  have "F n = 2 * (\<Sum>k=1..n. real (k - 1) / real (k * (k + 1)))" (is "_ = 2 * ?S") by (fact F_eq)
  also have "?S = (\<Sum>k=1..n. 2 / real (Suc k) - 1 / real k)"
    by (intro sum.cong) (simp_all add: field_simps of_nat_diff)
  also have "\<dots> = 2 * (\<Sum>k=1..n. inverse (real (Suc k))) - harm n"
    by (subst sum_subtractf) (simp add: harm_def sum.distrib sum_distrib_left divide_simps)
  also have "(\<Sum>k=1..n. inverse (real (Suc k))) = (\<Sum>k=Suc 1..Suc n. inverse (real k))"
    by (intro sum.reindex_bij_witness[of _ "\<lambda>x. x - 1" Suc]) auto
  also have "\<dots> = harm (Suc n) - 1" unfolding harm_def by (subst (2) sum_head_Suc) simp_all
  finally have "F n = 2 * harm n + 4 * (1 / (n + 1) - 1)" by (simp add: harm_Suc field_simps)
  also have "\<dots> * real (n + 1) = 2 * real (n + 1) * harm n - 4 * real n"
    by (simp add: field_simps)
  also have "F n * real (n + 1) = rqs_cost_exp n" by (simp add: F_def add_ac)
  finally show ?thesis .
qed

(* TODO Move *)
lemma asymp_equiv_harm [asymp_equiv_intros]: "harm \<sim> (\<lambda>n. ln (real n))"
proof -
  have "(\<lambda>n. harm n - ln (real n)) \<in> O(\<lambda>_. 1)" using euler_mascheroni_LIMSEQ
    by (intro bigoI_tendsto[where c = euler_mascheroni]) simp_all
  also have "(\<lambda>_. 1) \<in> o(\<lambda>n. ln (real n))" by auto
  finally have "(\<lambda>n. ln (real n) + (harm n - ln (real n))) \<sim> (\<lambda>n. ln (real n))"
    by (subst asymp_equiv_add_right) simp_all
  thus ?thesis by simp
qed
  
corollary rqs_cost_exp_asymp_equiv: "rqs_cost_exp \<sim> (\<lambda>n. 2 * n * ln n)"
proof -
  have "rqs_cost_exp = (\<lambda>n. 2 * real (n + 1) * harm n - 4 * real n)" using rqs_cost_exp_eq ..
  also have "\<dots> = (\<lambda>n. 2 * real n * harm n + (2 * harm n - 4 * real n))"
    by (simp add: algebra_simps)
  finally have "rqs_cost_exp \<sim> \<dots>" by simp
  also have "\<dots> \<sim> (\<lambda>n. 2 * real n * harm n)"
  proof (subst asymp_equiv_add_right)
    have "(\<lambda>x. 1 * harm x) \<in> o(\<lambda>x. real x * harm x)" 
      by (intro landau_o.small_big_mult smallo_real_nat_transfer) simp_all
    moreover have "harm \<in> \<omega>(\<lambda>_. 1 :: real)"
      by (intro smallomegaI_filterlim_at_top_norm) (auto simp: harm_at_top)
    hence "(\<lambda>x. real x * 1) \<in> o(\<lambda>x. real x * harm x)"
      by (intro landau_o.big_small_mult) (simp_all add: smallomega_iff_smallo)
    ultimately show "(\<lambda>n. 2 * harm n - 4 * real n) \<in> o(\<lambda>n. 2 * real n * harm n)"
      by (intro sum_in_smallo) simp_all
  qed simp_all
  also have "\<dots> \<sim> (\<lambda>n. 2 * real n * ln (real n))" by (intro asymp_equiv_intros)
  finally show ?thesis .
qed

end
