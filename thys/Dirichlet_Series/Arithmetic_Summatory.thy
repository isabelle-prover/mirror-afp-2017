(*
    File:      Arithmetic_Summatory.thy
    Author:    Manuel Eberl, TU München
*)
section \<open>Summatory arithmetic functions\<close>
theory Arithmetic_Summatory
  imports 
    More_Totient
    Moebius_Mu
    Liouville_Lambda
    Divisor_Count 
    Dirichlet_Series
begin

subsection \<open>Definition\<close>

definition sum_upto :: "(nat \<Rightarrow> 'a :: comm_monoid_add) \<Rightarrow> real \<Rightarrow> 'a" where
  "sum_upto f x = (\<Sum>i | 0 < i \<and> real i \<le> x. f i)"

lemma sum_upto_altdef: "sum_upto f x = (\<Sum>i\<in>{0<..nat \<lfloor>x\<rfloor>}. f i)"
  unfolding sum_upto_def
  by (cases "x \<ge> 0"; intro sum.cong refl) (auto simp: le_nat_iff le_floor_iff)
    
lemma sum_upto_0 [simp]: "sum_upto f 0 = 0"
  by (simp add: sum_upto_altdef)

lemma sum_upto_cong [cong]:
  "(\<And>n. n > 0 \<Longrightarrow> f n = f' n) \<Longrightarrow> n = n' \<Longrightarrow> sum_upto f n = sum_upto f' n'"
  by (simp add: sum_upto_def)

lemma finite_Nats_le_real [simp,intro]: "finite {n. 0 < n \<and> real n \<le> x}"
proof (rule finite_subset)
  show "finite {n. n \<le> nat \<lfloor>x\<rfloor>}" by auto
  show "{n. 0 < n \<and> real n \<le> x} \<subseteq> {n. n \<le> nat \<lfloor>x\<rfloor>}" by safe linarith
qed

lemma sum_upto_ind: "sum_upto (ind P) x = of_nat (card {n. n > 0 \<and> real n \<le> x \<and> P n})"
proof -
  have "sum_upto (ind P :: nat \<Rightarrow> 'a) x = (\<Sum>n | 0 < n \<and> real n \<le> x \<and> P n. 1)"
    unfolding sum_upto_def by (intro sum.mono_neutral_cong_right) (auto simp: ind_def)
  also have "\<dots> = of_nat (card {n. n > 0 \<and> real n \<le> x \<and> P n})" by simp
  finally show ?thesis .
qed

lemma sum_upto_dirichlet_prod:
  "sum_upto (dirichlet_prod f g) x = sum_upto (\<lambda>d. f d * sum_upto g (x / real d)) x"
proof -
  have "sum_upto (dirichlet_prod f g) x = 
          (\<Sum>n | 0 < n \<and> real n \<le> x. \<Sum>d | d dvd n. f d * g (n div d))"
    by (simp add: sum_upto_def dirichlet_prod_def)
  also have "\<dots> = (\<Sum>(n,d) \<in> (SIGMA n:{n. 0 < n \<and> real n \<le> x}. {d. d dvd n}). f d * g (n div d))"
    (is "_ = sum _ ?A") by (subst sum.Sigma) simp_all
  also have "\<dots> = (\<Sum>(d,n) \<in> (SIGMA d:{d. 0 < d \<and> real d \<le> x}. {n. d dvd n \<and> 0 < n \<and> real n \<le> x}). 
                     f d * g (n div d))"
    by (intro sum.reindex_bij_witness[of _ "\<lambda>(x,y). (y,x)" "\<lambda>(x,y). (y,x)"])
       (auto dest: dvd_imp_le elim: dvdE)
  also have "\<dots> = (\<Sum>d | 0 < d \<and> real d \<le> x. f d * 
                     (\<Sum>n | d dvd n \<and> 0 < n \<and> real n \<le> x. g (n div d)))"
    by (subst sum.Sigma [symmetric]) (simp_all add: sum_distrib_left)
  also have "\<dots> = (\<Sum>d | 0 < d \<and> real d \<le> x. f d * 
                     (\<Sum>n' | 0 < n' \<and> real n' \<le> x / real d. g n'))"
  proof (intro sum.cong refl, goal_cases)
    case (1 d)
    hence "(\<Sum>n | d dvd n \<and> 0 < n \<and> real n \<le> x. g (n div d)) =
             (\<Sum>n' | 0 < n' \<and> real n' \<le> x / real d. g n')"
      by (intro sum.reindex_bij_witness[of _ "\<lambda>n'. n' * d" "\<lambda>n. n div d"])
         (auto elim: dvdE simp: field_simps)
    thus ?case by simp
  qed
  also have "\<dots> = sum_upto (\<lambda>d. f d * sum_upto g (x / real d)) x"
    by (simp add: sum_upto_def)
  finally show ?thesis .
qed

lemma sum_upto_real: 
  assumes "x \<ge> 0"
  shows   "sum_upto real x = of_int (floor x) * (of_int (floor x) + 1) / 2"
proof -
  have A: "2 * \<Sum>{1..n} = n * Suc n" for n by (induction n) simp_all
  have "2 * sum_upto real x = real (2 * \<Sum>{0<..nat \<lfloor>x\<rfloor>})" by (simp add: sum_upto_altdef)
  also have "{0<..nat \<lfloor>x\<rfloor>} = {1..nat \<lfloor>x\<rfloor>}" by auto
  also note A
  also have "real (nat \<lfloor>x\<rfloor> * Suc (nat \<lfloor>x\<rfloor>)) = of_int (floor x) * (of_int (floor x) + 1)" using assms
    by (simp add: algebra_simps)
  finally show ?thesis by simp
qed


subsection \<open>The Hyperbola method\<close>

lemma hyperbola_method_semiring:
  fixes f g :: "nat \<Rightarrow> 'a :: comm_semiring_0"
  assumes "x \<ge> 0"
  shows   "sum_upto (dirichlet_prod f g) x + sum_upto f (sqrt x) * sum_upto g (sqrt x) = 
             sum_upto (\<lambda>n. f n * sum_upto g (x / real n)) (sqrt x) +
             sum_upto (\<lambda>n. sum_upto f (x / real n) * g n) (sqrt x)"
proof -
  {
    fix a b :: real assume ab: "a > 0" "b > 0" "x \<ge> 0" "a * b \<le> x" "a > sqrt x" "b > sqrt x"
    hence "a * b > sqrt x * sqrt x" by (intro mult_strict_mono) auto
    also from \<open>x \<ge> 0\<close> have "sqrt x * sqrt x = x" by simp
    finally have False using \<open>a * b \<le> x\<close> by simp
  } note * = this
  have *: "a \<le> sqrt x \<or> b \<le> sqrt x" if "a * b \<le> x" "a > 0" "b > 0" "x \<ge> 0" for a b
    by (rule ccontr) (insert *[of a b] that, auto)
  
  have nat_mult_leD1: "real a \<le> x" if "real a * real b \<le> x" "b > 0" for a b
  proof -
    from that have "real a * 1 \<le> real a * real b" by (intro mult_left_mono) simp_all
    also have "\<dots> \<le> x" by fact
    finally show ?thesis by simp
  qed
  have nat_mult_leD2: "real b \<le> x" if "real a * real b \<le> x" "a > 0" for a b
    using nat_mult_leD1[of b a] that by (simp add: mult_ac)
  
  have le_sqrt_mult_imp_le: "a * b \<le> x" 
    if "a \<ge> 0" "b \<ge> 0" "a \<le> sqrt x" "b \<le> sqrt x" for a b :: real
  proof -
    from that and assms have "a * b \<le> sqrt x * sqrt x" by (intro mult_mono) auto
    with assms show "a * b \<le> x" by simp
  qed
  
  define F G where "F = sum_upto f" and "G = sum_upto g"  
  let ?Bound = "{0<..nat \<lfloor>x\<rfloor>} \<times> {0<..nat \<lfloor>x\<rfloor>}"
  let ?B = "{(r,d). 0 < r \<and> real r \<le> sqrt x \<and> 0 < d \<and> real d \<le> x / real r}"
  let ?C = "{(r,d). 0 < d \<and> real d \<le> sqrt x \<and> 0 < r \<and> real r \<le> x / real d}"
  let ?B' = "SIGMA r:{r. 0 < r \<and> real r \<le> sqrt x}. {d. 0 < d \<and> real d \<le> x / real r}"
  have "sum_upto (dirichlet_prod f g) x + F (sqrt x) * G (sqrt x) = 
          (\<Sum>(i,(r,d)) \<in> (SIGMA i:{i. 0 < i \<and> real i \<le> x}. {(r,d). r * d = i}). f r * g d) + 
          sum_upto f (sqrt x) * sum_upto g (sqrt x)" (is "_ = ?S + _")
    unfolding sum_upto_def dirichlet_prod_altdef2 F_def G_def
    by (subst sum.Sigma) (auto intro: finite_divisors_nat')
  also have "?S = (\<Sum>(r,d) | 0 < r \<and> 0 < d \<and> real (r * d) \<le> x. f r * g d)"
    (is "_ = sum _ ?A") by (intro sum.reindex_bij_witness[of _ "\<lambda>(r,d). (r*d,(r,d))" snd]) auto
  also have "?A = ?B \<union> ?C" using assms by (auto simp: field_simps dest: *)
  also have "sum_upto f (sqrt x) * sum_upto g (sqrt x) = 
               (\<Sum>r | 0 < r \<and> real r \<le> sqrt x. \<Sum>d | 0 < d \<and> real d \<le> sqrt x. f r * g d)"
    by (simp add: sum_upto_def sum_product)
  also have "\<dots> = (\<Sum>(r,d)\<in>{r. 0 < r \<and> real r \<le> sqrt x} \<times> {d. 0 < d \<and> real d \<le> sqrt x}. f r * g d)"
    (is "_ = sum _ ?X") by (rule sum.cartesian_product)
  also have "?X = ?B \<inter> ?C" by (auto simp: field_simps le_sqrt_mult_imp_le)
  also have "(\<Sum>(r,d)\<in>?B \<union> ?C. f r * g d) + (\<Sum>(r,d)\<in>?B \<inter> ?C. f r * g d) = 
               (\<Sum>(r,d)\<in>?B. f r * g d) + (\<Sum>(r,d)\<in>?C. f r * g d)" using assms
    by (intro sum.union_inter finite_subset[of ?B ?Bound] finite_subset[of ?C ?Bound])
       (auto simp: le_nat_iff le_floor_iff field_simps dest: nat_mult_leD1 nat_mult_leD2)
  also have "(\<Sum>(r,d)\<in>?C. f r * g d) = (\<Sum>(r,d)\<in>?B. f d * g r)"
    by (intro sum.reindex_bij_witness[of _ "\<lambda>(x,y). (y,x)" "\<lambda>(x,y). (y,x)"]) auto
  also have "?B = ?B'" by auto
  hence "(\<lambda>f. sum f ?B) = (\<lambda>f. sum f ?B')" by simp
  also have "(\<Sum>(r,d)\<in>?B'. f r * g d) = sum_upto (\<lambda>n. f n * G (x / real n)) (sqrt x)"
    by (subst sum.Sigma [symmetric]) (simp_all add: sum_upto_def sum_distrib_left G_def)
  also have "(\<Sum>(r,d)\<in>?B'. f d * g r) = sum_upto (\<lambda>n. F (x / real n) * g n) (sqrt x)"
    by (subst sum.Sigma [symmetric]) (simp_all add: sum_upto_def sum_distrib_right F_def)
  finally show ?thesis by (simp only: F_def G_def)
qed
  
lemma hyperbola_method:
  fixes f g :: "nat \<Rightarrow> 'a :: comm_ring"
  assumes "x \<ge> 0"
  shows   "sum_upto (dirichlet_prod f g) x = 
             sum_upto (\<lambda>n. f n * sum_upto g (x / real n)) (sqrt x) +
             sum_upto (\<lambda>n. sum_upto f (x / real n) * g n) (sqrt x) -
             sum_upto f (sqrt x) * sum_upto g (sqrt x)"
  using hyperbola_method_semiring[OF assms, of f g] by (simp add: algebra_simps)

end
