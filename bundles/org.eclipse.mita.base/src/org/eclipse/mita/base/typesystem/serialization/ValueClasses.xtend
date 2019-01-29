package org.eclipse.mita.base.typesystem.serialization

import java.util.ArrayList
import java.util.List
import java.util.Map
import java.util.Set
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy.AmbiguityResolutionStrategy
import org.eclipse.mita.base.typesystem.types.Signedness
import org.eclipse.mita.base.typesystem.types.Variance
import org.eclipse.xtext.diagnostics.Severity


final class SerializedConstraintSystem {
	public List<SerializedAbstractTypeConstraint> constraints = new ArrayList;
	public Map<String, Object> symbolTable;
	public Map<String, Object> typeTable;
	public Map<String, Object> typeClasses;
	public SerializedAbstractTypeGraph explicitSubtypeRelations;
	public Map<Integer, Object> explicitSubtypeRelationsTypeSource;
}

final class SerializedAbstractTypeGraph {    
	public Map<Integer, Set<Integer>> outgoing;
	public Map<Integer, Set<Integer>> incoming;
	public Map<Integer, SerializedAbstractType> nodeIndex;
	public int nextNodeInt = 0;
}

final class SerializedValidationIssue {	
	public Severity severity;
	public String message;
	public String issueCode;
	public String target;
	public SerializedFeature feature;
}

final class SerializedTypeClass {
	public Map<SerializedAbstractType, String> instances;
}

final class SerializedTypeClassProxy {
	public SerializedTypeVariableProxy toResolve;
}

abstract class SerializedAbstractType {
	public String origin;
	public String name;
	public Map<String, String> userData;
}

abstract class SerializedAbstractBaseType extends SerializedAbstractType {
}

final class SerializedTypeHole extends SerializedAbstractType {
}

final class SerializedUnorderedArguments extends SerializedCompoundType {
    public List<String> parameterNames = new ArrayList;
    public List<SerializedAbstractType> valueTypes = new ArrayList;
}

final class SerializedAtomicType extends SerializedAbstractBaseType {
}

final class SerializedBaseKind extends SerializedAbstractBaseType {
	public SerializedAbstractType kindOf;
}

final class SerializedBottomType extends SerializedAbstractBaseType {
	public String message;
}

abstract class SerializedNumericType extends SerializedAbstractBaseType {
	public int widthInBytes;
}

final class SerializedFloatingType extends SerializedNumericType {
}

final class SerializedIntegerType extends SerializedNumericType {
	public Signedness signedness;
}

abstract class SerializedCompoundType extends SerializedAbstractType {
	public SerializedAbstractType type;
	public List<SerializedAbstractType> typeArguments = new ArrayList;
}

final class SerializedTypeConstructorType extends SerializedCompoundType {
}

final class SerializedFunctionType extends SerializedCompoundType {
}

final class SerializedProductType extends SerializedCompoundType {
}

final class SerializedSumType extends SerializedCompoundType {
}

final class SerializedTypeScheme extends SerializedAbstractType {
	public List<SerializedTypeVariable> vars;
	public SerializedAbstractType on;
}

final class SerializedTypeVariable extends SerializedAbstractType {
}

final class SerializedTypeVariableProxy extends SerializedAbstractType {
	public SerializedEReference reference;
	public String targetQID;
	public AmbiguityResolutionStrategy ambiguityResolutionStrategy;
}

abstract class SerializedAbstractTypeConstraint {
	public SerializedValidationIssue errorMessage;
}

final class SerializedEqualityConstraint extends SerializedAbstractTypeConstraint {
	public SerializedAbstractType left;
	public SerializedAbstractType right;
}

final class SerializedJavaClassInstanceConstraint extends SerializedAbstractTypeConstraint {
	public SerializedAbstractType what;
	public String javaClass;
}

final class SerializedExplicitInstanceConstraint extends SerializedAbstractTypeConstraint {
	public SerializedAbstractType instance;
	public SerializedAbstractType typeScheme;
}

final class SerializedSubtypeConstraint extends SerializedAbstractTypeConstraint {
	public SerializedAbstractType subType;
	public SerializedAbstractType superType;
}

abstract class SerializedFeature {
	public String javaClass;
	public String javaField;
	public String javaMethod;
	public String ePackageName;
	public String eClassName;
	public String eReferenceName;
}

final class SerializedEStructuralFeature extends SerializedFeature {
}

final class SerializedEReference extends SerializedFeature {
}
 
final class SerializedFunctionTypeClassConstraint extends SerializedAbstractTypeConstraint {
	public SerializedAbstractType type;
	public String functionCall;
	public Object functionReference;
	public SerializedTypeVariable returnTypeTV;
	public String instanceOfQN;
	public Variance returnTypeVariance;
}

