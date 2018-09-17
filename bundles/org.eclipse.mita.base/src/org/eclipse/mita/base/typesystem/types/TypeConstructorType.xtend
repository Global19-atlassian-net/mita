package org.eclipse.mita.base.typesystem.types

import java.util.ArrayList
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint

import static extension org.eclipse.mita.base.util.BaseUtils.force;
import org.eclipse.xtext.scoping.IScopeProvider

@FinalFieldsConstructor
@EqualsHashCode
@Accessors
class TypeConstructorType extends AbstractType {
	protected static Integer instanceCount = 0;
	protected val List<AbstractType> typeArguments;
	// transient makes EqualsHashCode ignore this
	protected final transient List<AbstractType> superTypes = new ArrayList();
	
	new(EObject origin, String name, Iterable<AbstractType> typeArguments, Iterable<AbstractType> superTypes) {
		this(origin, name, typeArguments.force);
		this.superTypes += superTypes;
	}
	
	def AbstractTypeConstraint getVariance(int typeArgumentIdx, AbstractType tau, AbstractType sigma) {
		return new EqualityConstraint(tau, sigma, "TCT:30");
	}
	def void expand(Substitution s, TypeVariable tv) {
		val newTypeVars = typeArguments.map[ new TypeVariable(it.origin) as AbstractType ].force;
		val newCType = new TypeConstructorType(origin, name, newTypeVars, superTypes);
		s.add(tv, newCType);
	}
		
	override toString() {
		return '''«super.toString»«IF !typeArguments.empty»<«typeArguments.join(", ")»>«ENDIF»«IF !superTypes.empty» ⩽ «superTypes.map[it.name]»«ENDIF»'''
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return new TypeConstructorType(origin, name, typeArguments.map[it.replace(from, with)].force, superTypes);
	}
	
	override getFreeVars() {
		return typeArguments.flatMap[it.freeVars];
	}
	
	override toGraphviz() {
		'''«FOR t: typeArguments»"«t»" -> "«this»"; "«this»" -> "«t»" «t.toGraphviz»«ENDFOR»''';
	}
	
	override replace(Substitution sub) {
		return new TypeConstructorType(origin, name, typeArguments.map[it.replace(sub)].force, superTypes);
	}
	
	override instantiate() {
		val ts = new TypeScheme(null, freeVars.toList, this);
		return ts.instantiate;
	}
	
	override replaceProxies(IScopeProvider scopeProvider) {
		return new TypeConstructorType(origin, name, typeArguments.map[it.replaceProxies(scopeProvider)], superTypes);
	}	
}