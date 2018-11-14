package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.Argument
import org.eclipse.mita.base.expressions.util.ExpressionUtils
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.Parameter
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.FunctionTypeClassConstraint
import org.eclipse.mita.base.typesystem.constraints.ImplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.JavaClassInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.infra.Graph
import org.eclipse.mita.base.typesystem.types.AbstractBaseType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.typesystem.types.UnorderedArguments
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.init
import static extension org.eclipse.mita.base.util.BaseUtils.unzip
import static extension org.eclipse.mita.base.util.BaseUtils.zip
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.mita.base.expressions.ExpressionsPackage

/**
 * Solves coercive subtyping as described in 
 * Extending Hindley-Milner Type Inference with Coercive Structural Subtyping
 * Traytel et al., https://www21.in.tum.de/~nipkow/pubs/aplas11.pdf
 */
class CoerciveSubtypeSolver implements IConstraintSolver {
	@Inject
	protected MostGenericUnifierComputer mguComputer
	
	@Inject
	protected Provider<ConstraintSystem> constraintSystemProvider;
	
	@Inject 
	protected Provider<Substitution> substitutionProvider;
	
	@Inject
	protected ConstraintGraphProvider constraintGraphProvider;
	
	@Inject
	protected StdlibTypeRegistry typeRegistry;
	
	val enableDebug = true;
	
	override ConstraintSolution solve(ConstraintSystem system, EObject typeResolutionOrigin) {
		val debugOutput = enableDebug && typeResolutionOrigin.eResource.URI.lastSegment == "application.mita";
		
		var currentSystem = system;
		var currentSubstitution = Substitution.EMPTY;
		if(typeResolutionOrigin.eIsProxy) {
			return new ConstraintSolution(system, currentSubstitution, #[new UnificationIssue(typeResolutionOrigin, "typeResolutionOrigin must not be a proxy")]);
		}
		var ConstraintSolution result = null;
		if(!system.isWeaklyUnifiable()) {
			return new ConstraintSolution(system, null, #[ new UnificationIssue(system, 'Subtype solving cannot terminate') ]);
		}
		var issues = newArrayList;
		for(var i = 0; i < 10; i++) {
			if(debugOutput) {
				println("------------------")
				println(currentSystem);
			}
			val simplification = currentSystem.simplify(currentSubstitution, typeResolutionOrigin);
			if(!simplification.valid) {
				if(simplification?.system?.constraints.nullOrEmpty || simplification?.substitution?.content?.entrySet.nullOrEmpty) {
					return new ConstraintSolution(currentSystem, simplification.substitution, simplification.issues);
				}
				else {
					issues += simplification.issues;
//					return new ConstraintSolution(simplification.system, simplification.substitution, #[simplification.issue])
				}
			}
			val simplifiedSystem = simplification.system;
			val simplifiedSubst = simplification.substitution;
			if(debugOutput) {
				println(simplification);
			}
			val solution = solveSubtypeConstraints(simplifiedSystem, simplifiedSubst, typeResolutionOrigin);
			if(!solution.issues.empty) {
				if(solution?.constraints?.constraints.nullOrEmpty || solution?.solution?.content?.entrySet.nullOrEmpty) {
					return new ConstraintSolution(simplifiedSystem, simplifiedSubst, solution.issues);
				}
				else {
					issues += solution.issues;
					//return new ConstraintSolution(solution.constraints, solution.solution, solution.issues);
				}
			}
			result = solution;
			currentSubstitution = result.solution;
			currentSystem = currentSubstitution.apply(result.constraints);
		}
		return new ConstraintSolution(currentSystem, currentSubstitution, issues);
	}
	
	protected def ConstraintSolution solveSubtypeConstraints(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin) {
		val debugOutput = enableDebug && typeResolutionOrigin.eResource.URI.lastSegment == "application.mita";
		
		val constraintGraphAndSubst = system.buildConstraintGraph(substitution, typeResolutionOrigin);
		if(!constraintGraphAndSubst.value.valid) {
			val failure = constraintGraphAndSubst.value;
			return new ConstraintSolution(system, failure.substitution, failure.issues);
		}
		val constraintGraph = constraintGraphAndSubst.key;
		val constraintGraphSubstitution = constraintGraphAndSubst.value.substitution;
		if(debugOutput) {
			println("------------------")
			println(constraintGraph.toGraphviz());
			println(constraintGraphSubstitution);
		}		
		val resolvedGraphAndSubst = constraintGraph.resolve(constraintGraphSubstitution, typeResolutionOrigin);
		if(!resolvedGraphAndSubst.value.valid) {
			val failure = resolvedGraphAndSubst.value;
			return new ConstraintSolution(system, failure.substitution, failure.issues);
		}
		val resolvedGraph = resolvedGraphAndSubst.key;
		val resolvedGraphSubstitution = resolvedGraphAndSubst.value.substitution;
		if(debugOutput) {
			println("------------------")
			println(resolvedGraphSubstitution);
		}		
		val solution = resolvedGraph.unify(resolvedGraphSubstitution);
		
		return new ConstraintSolution(system, solution.substitution, solution.issues.filterNull.toList);
	}
	
	protected def boolean isWeaklyUnifiable(ConstraintSystem system) {
		// TODO: implement me
		return true;
	}
	
	protected def SimplificationResult simplify(ConstraintSystem system, Substitution subtitution, EObject typeResolutionOrigin) {
		var resultSystem = system;
		var resultSub = subtitution;
		var issues = newArrayList;
		while(resultSystem.hasNonAtomicConstraints()) {
			val constraintAndSystem = resultSystem.takeOneNonAtomic();
			val constraint = constraintAndSystem.key;
			val constraintSystem = constraintAndSystem.value;

			val simplification = doSimplify(constraintSystem, resultSub, typeResolutionOrigin, constraint);
			if(!simplification.valid) {
				issues += simplification.issues;
				// just throw out the constraint for now
				resultSystem = constraintSystem;
				//return SimplificationResult.failure(simplification.issue);
			}
			else {
				val witnessNotWeaklyUnifyable = simplification.substitution.content.entrySet.findFirst[tv_t | tv_t.key != tv_t.value && tv_t.value.freeVars.exists[it == tv_t.key]];
				if(witnessNotWeaklyUnifyable !== null) {
					return new SimplificationResult(resultSub, #[new UnificationIssue(witnessNotWeaklyUnifyable, "System is not weakly unifyable")], resultSystem);
				}	
				resultSub = simplification.substitution;
				resultSystem = resultSub.apply(simplification.system);
			}
		}
		
		return new SimplificationResult(resultSub, issues, resultSystem);
	}
		
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, ImplicitInstanceConstraint constraint) {
		system.doSimplify(substitution, typeResolutionOrigin, constraint, constraint.isInstance, constraint.ofType);	
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, ImplicitInstanceConstraint constraint, TypeConstructorType t1, TypeConstructorType t2) {
		if(t1.name == t2.name && t1.typeArguments.length == t2.typeArguments.length) {
			val newSystem = constraintSystemProvider.get();
			t1.typeArguments.zip(t2.typeArguments).forEach[
//				val leftType = it.key;
//				if(leftType instanceof TypeVariable) {
//					substitution.add(leftType, it.value);
//				}
				newSystem.addConstraint(new ImplicitInstanceConstraint(it.key, it.value, constraint.errorMessage));	
			]
			return SimplificationResult.success(ConstraintSystem.combine(#[system, newSystem]), substitution);
		}
		return SimplificationResult.failure(new UnificationIssue(#[t1, t2], '''CSS: «BaseUtils.lineNumber»: «constraint.errorMessage» -> «t1» not instance of «t2»'''));
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, ImplicitInstanceConstraint constraint, TypeVariable t1, TypeVariable t2) {
		return SimplificationResult.success(system, substitution);
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, ImplicitInstanceConstraint constraint, AbstractType t1, AbstractType t2) {
		if(t1 == t2) {
			return SimplificationResult.success(system, substitution);
		}
		return SimplificationResult.failure(new UnificationIssue(#[t1, t2], '''CSS: «BaseUtils.lineNumber»: «constraint.errorMessage» -> «t1» not instance of «t2»'''));
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, ExplicitInstanceConstraint constraint) {
		val instance = constraint.typeScheme.instantiate(system);
		val instanceType = instance.value
		val resultSystem = system.plus(
			new EqualityConstraint(constraint.instance, instanceType, "CSS:133")
		)
		return SimplificationResult.success(resultSystem, substitution);
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, JavaClassInstanceConstraint constraint) {
		if(constraint.javaClass.isInstance(constraint.what)) {
			return SimplificationResult.success(system, substitution);
		}
		return SimplificationResult.failure(new UnificationIssue(constraint.what.origin, '''CSS: «BaseUtils.lineNumber»: «constraint.errorMessage» -> «constraint.what» is not instance of «constraint.javaClass.simpleName»'''));
	}
	
	@FinalFieldsConstructor
	@Accessors
	@EqualsHashCode
	private static class TypeClassConstraintResolutionResult {
		val UnificationResult unificationResult;
		val AbstractType functionType;
		val EObject function;
		val double distanceToTargetType;
		
		override toString() {
			if(unificationResult?.valid) {
				return '''«functionType» (dist: «distanceToTargetType»)'''				
			}
			else {
				return '''INVALID: «unificationResult.issues»'''
			}
		}
		
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, FunctionTypeClassConstraint constraint) {
		val refType = constraint.typ;
		val typeClass = system.typeClasses.get(constraint.instanceOfQN);
		if(typeClass !== null && typeClass.instances.containsKey(refType)) {
			val fun = typeClass.instances.get(refType);
			if(fun instanceof Operation) {
				return constraint.onResolve(system, substitution, fun, refType);				
			}
			else {
				return SimplificationResult.failure(new UnificationIssue(constraint, '''CSS: «constraint.errorMessage» -> «fun» not an Operation'''))
			}
		}
		if(typeClass !== null) {
			val unificationResults = typeClass.instances.entrySet.map[k_v | 
				val typRaw = k_v.key;
				val EObject fun = k_v.value;
				// typRaw might be a typeScheme (int32 -> b :: id: \T.T -> T)
				val typ_distance = if(typRaw instanceof TypeScheme) {
					typRaw.instantiate(system).value -> Double.POSITIVE_INFINITY
				} else {
					typRaw -> 0.0;
				}
				val typ = typ_distance.key;
				val distance = typ_distance.value;
				// handle named parameters: if _refType is unorderedArgs, sort them
				val prodType = if(refType instanceof UnorderedArguments) {
					val sortedArgs = ExpressionUtils.getSortedArguments((fun as Operation).parameters, refType.argParamNamesAndValueTypes, [it], [it.key]);
					new ProdType(refType.origin, refType.name, sortedArgs.map[it.value], refType.superTypes);
				} else {
					refType;
				}
					
				// two possible ways to be part of this type class:
				// - via subtype (uint8 < uint32)
				// - via instantiation/unification 
				if(typ instanceof FunctionType) {
					val optMsg = typeRegistry.isSubtypeOf(typeResolutionOrigin, prodType, typ.from);
					val mbUnification = mguComputer.compute(prodType, typ.from);
					val unification = if(optMsg.present && !mbUnification.valid) {
						UnificationResult.failure(refType, optMsg.get);
					} else {
						// TODO insert coercion
						if(!optMsg.present) {
							UnificationResult.success(Substitution.EMPTY);
						}
						else {
							mbUnification;
						}
					}
					return new TypeClassConstraintResolutionResult(unification, typ, fun, distance);
				}

				return new TypeClassConstraintResolutionResult(UnificationResult.failure(refType, '''«constraint.errorMessage» -> «typ» is not a function type'''), typ, fun, distance);
			].toList
			val processedResultsUnsorted = unificationResults.map[
				if(!it.unificationResult.valid) {
					return it;
				}
				val sub = substitution.apply(it.unificationResult.substitution);
				val resultType = sub.applyToType(it.functionType);
				new TypeClassConstraintResolutionResult(UnificationResult.success(sub), resultType, it.function, it.distanceToTargetType + computeDistance(refType, resultType))
			].toList
			val processedResults = processedResultsUnsorted
				.sortBy[it.distanceToTargetType].toList;
			val result = processedResults.findFirst[
				it.unificationResult.valid //&& it.function instanceof Operation
			]
			if(result !== null) {
				val sub = result.unificationResult.substitution;
				return constraint.onResolve(system, sub, result.function, result.functionType);
			}
		}
		return SimplificationResult.failure(new UnificationIssue(constraint, '''CSS: «constraint.errorMessage» -> «refType» not instance of «typeClass»'''))
	}
		
	dispatch def double computeDistance(AbstractType type, FunctionType type2) {
		return doComputeDistance(type, type2.from);
	}
	dispatch def double computeDistance(AbstractType type, AbstractType type2) {
		return Double.POSITIVE_INFINITY;
	}
	
	dispatch def double doComputeDistance(TypeConstructorType type, TypeConstructorType type2) {
		return type.typeArguments.zip(type2.typeArguments).fold(0.0, [sum, t1_t2 | sum + t1_t2.key.doComputeDistance(t1_t2.value)])
	}		
	dispatch def double doComputeDistance(AbstractType type, AbstractType type2) {
		if(type == type2) {
			return 0;
		}
		return Double.POSITIVE_INFINITY;
	}
	dispatch def double doComputeDistance(IntegerType type, IntegerType type2) {
		return Math.abs(type.widthInBytes - type2.widthInBytes);
	}
	
		
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, Object constraint) {
		SimplificationResult.failure(new UnificationIssue(substitution, println('''CSS: doSimplify not implemented for «constraint»''')))
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, Void constraint) {
		SimplificationResult.failure(new UnificationIssue(substitution, println('''CSS: doSimplify not implemented for null''')))
	}
	
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, EqualityConstraint constraint) {
		val t1 = constraint.left;
		val t2 = constraint.right;
		return system.doSimplify(substitution, typeResolutionOrigin, constraint, t1, t2);
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, EqualityConstraint constraint, TypeScheme t1, AbstractType t2) {
		val unification = mguComputer.compute(t1, t2);
		if(unification.valid) {
			return SimplificationResult.success(system, substitution.apply(unification.substitution));
		}
		return SimplificationResult.failure(unification.issues);
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, EqualityConstraint constraint, AbstractType t1, TypeScheme t2) {
		return system.doSimplify(substitution, typeResolutionOrigin, constraint, t2, t1);
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, EqualityConstraint constraint, AbstractType t1, AbstractType t2) {
		// unify
		val mgu = mguComputer.compute(t1, t2);
		if(!mgu.valid) {
			return SimplificationResult.failure(mgu.issues);
		}
		
		return SimplificationResult.success(mgu.substitution.apply(system), mgu.substitution.apply(substitution));
	}
		
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint) {
		val sub = constraint.subType;
		val top = constraint.superType;
		
		val result = doSimplify(system, substitution, typeResolutionOrigin, constraint, sub, top);
		return result;
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint, SumType sub, SumType top) {
		return system._doSimplify(substitution, typeResolutionOrigin, constraint, sub as TypeConstructorType, top as TypeConstructorType);
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint, TypeConstructorType sub, SumType top) {
		val subTypes = typeRegistry.getSubTypes(top, typeResolutionOrigin).toSet;
		val similarSubTypes = subTypes.filter[sub.class == it.class];
		val subTypesWithSameName = subTypes.filter[sub.name == it.name];
		if(subTypes.contains(sub)) {
			return SimplificationResult.success(system, substitution);
		}
		val topTypes = typeRegistry.getSuperTypes(system, sub, typeResolutionOrigin);
		val similarTopTypes = topTypes.filter[it.class == top.class];
		val superTypesWithSameName = topTypes.filter[it.name == top.name];
		if(topTypes.contains(top)) {
			return SimplificationResult.success(system, substitution);
		} 
		
		if(similarSubTypes.size == 1) {
			return system.doSimplify(substitution, typeResolutionOrigin, constraint, sub, similarSubTypes.head);
		}
		if(similarTopTypes.size == 1) {
			return system.doSimplify(substitution, typeResolutionOrigin, constraint, similarTopTypes.head, top);
		}
		
		if(similarSubTypes.size > 1) {
			return similarSubTypes.map[system.doSimplify(substitution, typeResolutionOrigin, constraint, sub, it)].reduce[p1, p2| p1.or(p2)]
		}
		if(similarTopTypes.size > 1) {
			return similarTopTypes.map[system.doSimplify(substitution, typeResolutionOrigin, constraint, it, top)].reduce[p1, p2| p1.or(p2)]
		}
		
		if(subTypesWithSameName.size == 1) {
			return system.doSimplify(substitution, typeResolutionOrigin, constraint, sub, subTypesWithSameName.head);
		}
	
		if(superTypesWithSameName.size == 1) {
			return system._doSimplify(substitution, typeResolutionOrigin, constraint, superTypesWithSameName.head, top);
		}
	
	
		//TODO: handle multiple super types with same name
		//already handled: superTypesWithSameName.empty --> failure
		return SimplificationResult.failure(new UnificationIssue(#[sub, top], '''CSS: «constraint.errorMessage» -> «sub» is not a subtype of «top»'''))
	}
	
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint, TypeConstructorType sub, TypeConstructorType top) {
		val typeArgs1 = sub.typeArguments.force;
		val typeArgs2 = top.typeArguments.force;
		if(typeArgs1.length !== typeArgs2.length) {
			return SimplificationResult.failure(new UnificationIssue(#[sub, top], '''CSS: «constraint.errorMessage» -> «sub» and «top» differ in their type arguments'''));
		}
		if(sub.class != top.class) {
			return SimplificationResult.failure(new UnificationIssue(#[sub, top], '''CSS: «constraint.errorMessage» -> «sub» and «top» are not constructed the same'''));
		}
		
		val typeArgs = sub.typeArguments.zip(top.typeArguments).indexed;
		val nc = constraintSystemProvider.get();
		typeArgs.forEach[i_t1t2 |
			val tIdx = i_t1t2.key;
			val tSub = i_t1t2.value.key;
			val tTop = i_t1t2.value.value;
			nc.addConstraint(sub.getVariance(tIdx, tSub, tTop));
		]
		
		return SimplificationResult.success(ConstraintSystem.combine(#[system, nc]), substitution);
		
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint, TypeVariable sub, TypeConstructorType top) {
		// expand-l:   a <: Ct1...tn
		val expansion = substitutionProvider.get() => [top.expand(system, it, sub)];
		val newSystem = expansion.apply(system.plus(new SubtypeConstraint(sub, top, constraint.errorMessage)));
		val newSubstitution = expansion.apply(substitution);
		return SimplificationResult.success(newSystem, newSubstitution);
	} 
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint, TypeConstructorType sub, TypeVariable top) {
		// expand-r:   Ct1...tn <: a
		val expansion = substitutionProvider.get() => [sub.expand(system, it, top)];
		val newSystem = expansion.apply(system.plus(new SubtypeConstraint(sub, top, constraint.errorMessage)));
		val newSubstitution = expansion.apply(substitution);
		return SimplificationResult.success(newSystem, newSubstitution);
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint, AbstractBaseType sub, AbstractBaseType top) { 
		// eliminate:  U <: T
		val issue = typeRegistry.isSubtypeOf(typeResolutionOrigin, sub, top);
		if(issue.present) {
			return SimplificationResult.failure(new UnificationIssue(#[sub, top], constraint.errorMessage + " -> " + issue.get()));
		} else {
			return SimplificationResult.success(system, substitution);
		}
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint, AbstractType sub, AbstractType top) { 
		// eliminate:  U <: T
		val issue = typeRegistry.isSubtypeOf(typeResolutionOrigin, sub, top);
		if(issue.present) {
			return SimplificationResult.failure(new UnificationIssue(#[sub, top], constraint.errorMessage + " -> " + issue.get()));
		} else {
			return SimplificationResult.success(system, substitution);
		}
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint, TypeScheme sub, AbstractType top) {
		val vars_instance = sub.instantiate(system)
		val newSystem = system.plus(new SubtypeConstraint(vars_instance.value, top, constraint.errorMessage));
		return SimplificationResult.success(newSystem, substitution);
	} 
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, SubtypeConstraint constraint, Object sub, Object top) {
		SimplificationResult.failure(new UnificationIssue(substitution, println('''CSS: doSimplify.SubtypeConstraint not implemented for «sub.class.simpleName» and «top.class.simpleName»''')))
	}
		
	protected def Pair<ConstraintGraph, UnificationResult> buildConstraintGraph(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin) {
		val gWithCycles = constraintGraphProvider.get(system, typeResolutionOrigin);
		if(enableDebug) {
			println(gWithCycles.toGraphviz);
		}
		val finalState = new Object() {
			var Substitution s = substitution;
			var Boolean success = true;
			var String msg = "";
			var Iterable<Pair<AbstractType, AbstractType>> origin = null;
		}
		val gWithoutCycles = Graph.removeCycles(gWithCycles, [cycle | 
			val mgu = mguComputer.compute(cycle); 
			if(mgu.valid) {
				val newTypes = mgu.substitution.applyToTypes(cycle.flatMap[t1_t2 | #[t1_t2.key, t1_t2.value]]);
				finalState.s = finalState.s.apply(mgu.substitution);
				return newTypes.head;
			}
			else {
				finalState.success = false;
				finalState.origin = cycle.toList;
				finalState.msg = '''CSS: Cyclic dependencies could not be resolved: «finalState.origin.map[it.key.origin ?: it.key].join(' ⩽ ')»''';
				return new BottomType(null, finalState.msg);
			}
		])
		if(finalState.success) {
			return (gWithoutCycles -> UnificationResult.success(finalState.s));
		}
		else {
			return (gWithoutCycles -> UnificationResult.failure(finalState.origin, finalState.msg));
		}
	}
	
	protected def Pair<ConstraintGraph, UnificationResult> resolve(ConstraintGraph graph, Substitution _subtitution, EObject typeResolutionOrigin) {
		val varIdxs = graph.typeVariables;
		var resultSub = _subtitution;
		for(vIdx : varIdxs) {
			val v = graph.nodeIndex.get(vIdx) as TypeVariable;
			val predecessors = graph.getBaseTypePredecessors(vIdx);
			val supremum = graph.getSupremum(predecessors);
			val successors = graph.getBaseTypeSuccecessors(vIdx);
			val infimum = graph.getInfimum(successors);
			val supremumIsValid = supremum !== null && successors.forall[ t | typeRegistry.isSubType(typeResolutionOrigin, supremum, t) ];
			val infimumIsValid = infimum !== null && predecessors.forall[ t | typeRegistry.isSubType(typeResolutionOrigin, t, infimum) ];

			if(!predecessors.empty) {
				if(supremumIsValid) {
					// assign-sup
					graph.replace(v, supremum);
					resultSub = resultSub.replace(v, supremum) => [add(v, supremum)];
				} else {
					//redo for debugging
					graph.getBaseTypePredecessors(vIdx);
					graph.getSupremum(predecessors);
					supremum !== null && successors.forall[ t | 
						typeRegistry.isSubType(typeResolutionOrigin, supremum, t)
					];
					return null -> UnificationResult.failure(v, "CSS: Unable to find valid subtype for " + v.name);					
				}
			}
			else if(!successors.empty) {
				if(infimumIsValid) {
					// assign-inf
					graph.replace(v, infimum);
					resultSub = resultSub.replace(v, infimum) => [add(v, infimum)];
				} else {
					return null -> UnificationResult.failure(v, "CSS: Unable to find valid supertype for " + v.name);
				}
			}
			if(enableDebug) {
				println(graph.toGraphviz);
			}
		}
		return graph -> UnificationResult.success(resultSub);
	}
	
	protected def UnificationResult unify(ConstraintGraph graph, Substitution substitution) {
		val loselyConnectedComponents = graph.typeVariables.map[graph.looselyConnectedComponent(it)].toSet;
		loselyConnectedComponents.map[it.map[ni | graph.nodeIndex.get(ni)].toList].fold(UnificationResult.success(substitution), [ur, lcc |
			if(ur.valid === false) {
				return ur;
			}
			val lccEdges = lcc.tail.zip(lcc.init);
			val sub = ur.substitution;
			return unify(lccEdges, sub);
		])
	}
	protected def UnificationResult unify(Iterable<Pair<AbstractType, AbstractType>> loselyConnectedComponents, Substitution substitution) {
		var result = substitution;
		for(w: loselyConnectedComponents) {
			val unification = mguComputer.compute(w.key, w.value);
			if(!unification.valid) {
				return unification;
			}
			result = unification.substitution.apply(result);
		}
		return UnificationResult.success(result);
	}

}

class ConstraintGraphProvider implements Provider<ConstraintGraph> {
	
	@Inject 
	StdlibTypeRegistry typeRegistry;
	
	@Inject
	Provider<ConstraintSystem> constraintSystemProvider;
	
	override get() {
		return new ConstraintGraph(constraintSystemProvider.get(), typeRegistry, null);
	}
	
	def get(ConstraintSystem system, EObject typeResolutionOrigin) {
		return new ConstraintGraph(system, typeRegistry, typeResolutionOrigin);
	}
}

class ConstraintGraph extends Graph<AbstractType> {
	
	protected val StdlibTypeRegistry typeRegistry;
	protected val ConstraintSystem constraintSystem;
	protected val EObject typeResolutionOrigin;
	
	new(ConstraintSystem system, StdlibTypeRegistry typeRegistry, EObject typeResolutionOrigin) {
		this.typeRegistry = typeRegistry;
		this.constraintSystem = system;
		this.typeResolutionOrigin = typeResolutionOrigin;
		system.constraints
			.filter(SubtypeConstraint)
			.forEach[ addEdge(it.subType, it.superType) ];
	}
	def getTypeVariables() {
		return nodeIndex.filter[k, v| v instanceof TypeVariable].keySet;
	}
	def getBaseTypePredecessors(Integer t) {
		return getPredecessors(t).filter(AbstractBaseType).force
	}

	def getBaseTypeSuccecessors(Integer t) {
		return getSuccessors(t).filter(AbstractBaseType).force
	}
	
	def <T extends AbstractType> getSupremum(Iterable<T> ts) {
		val tsCut = ts.map[
			typeRegistry.getSuperTypes(constraintSystem, it, typeResolutionOrigin).toSet
		].reduce[s1, s2| s1.reject[!s2.contains(it)].toSet] ?: #[].toSet; // cut over emptySet is emptySet
		return tsCut.findFirst[candidate | 
			tsCut.forall[u | 
				typeRegistry.isSubType(u.origin, candidate, u)
			]
		];
	}
	
	def <T extends AbstractType> getInfimum(Iterable<T> ts) {
		val tsCut = ts.map[typeRegistry.getSubTypes(it, typeResolutionOrigin).toSet].reduce[s1, s2| s1.reject[!s2.contains(it)].toSet] ?: #[].toSet;
		return tsCut.findFirst[candidate | tsCut.forall[l | typeRegistry.isSubType(l.origin, l, candidate)]];
	}
	
	def getSupremum(AbstractType t) {
		return getSupremum(#[t])
	}
	
	def getInfimum(AbstractType t) {
		return getInfimum(#[t])
	}
	
	override nodeToString(Integer i) {
		val t = nodeIndex.get(i);
		if(t?.origin === null) {
			return super.nodeToString(i)	
		}
		return '''«t.origin»(«t», «i»)'''
	}
	
	override addEdge(Integer fromIndex, Integer toIndex) {
		if(fromIndex == toIndex) {
			return;
		}
		super.addEdge(fromIndex, toIndex);
	}
	
	override replace(AbstractType from, AbstractType with) {
		super.replace(from, with)
		constraintSystem?.explicitSubtypeRelations?.replace(from, with);
	}
	
} 

@FinalFieldsConstructor
@Accessors
class SimplificationResult extends UnificationResult {
	protected final ConstraintSystem system;
	
	static def success(ConstraintSystem s, Substitution sigma) {
		return new SimplificationResult(sigma, #[], s);
	}
	
	static def SimplificationResult failure(Iterable<? extends UnificationIssue> issues) {
		return new SimplificationResult(null, issues, null);
	}
	static def SimplificationResult failure(UnificationIssue issue) {
		return new SimplificationResult(null, #[issue], null);
	}
	
	override toString() {
		if(isValid) {
			system.toString
		}
		else {
			""
		} + "\n" + super.toString()
	}
	
	def SimplificationResult or(SimplificationResult other) {
		if(this.valid) {
			if(other.valid) {
				return new SimplificationResult(this.substitution.apply(other.substitution), null, ConstraintSystem.combine(#[this.system, other.system]))
			}
			else {
				return this;
			}
		}
		else {
			if(other.valid) {
				return other;
			}
			else {
				return new SimplificationResult(null, this.issues + other.issues, null);
			}
		}
		
	}
}