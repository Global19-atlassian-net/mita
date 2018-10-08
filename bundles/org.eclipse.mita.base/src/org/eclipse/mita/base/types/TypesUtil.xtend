/** 
 * Copyright (c) 2016 committers of YAKINDU and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 * Contributors:
 * committers of YAKINDU - initial API and implementation
 */
package org.eclipse.mita.base.types

import org.eclipse.emf.common.util.BasicEList
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.mita.base.types.TypesPackage

/** 
 * @author Thomas Kutz - Initial contribution and API
 */
class TypesUtil {
	public static final String ID_SEPARATOR = "."

	def static String computeQID(NamedElement element) {
		if (element.getName() === null) {
			return null
		}
		var StringBuilder id = new StringBuilder()
		id.append(element.getName())
		var EObject container = element.eContainer()
		// -1 -> 0, 0 -> 1, ...
		val idx = container.eContents.indexOf(element) + 1;
		id.append("_");
		id.append(idx);
		while (container !== null) {
			if (container.eClass().getEAllStructuralFeatures().contains(TypesPackage.Literals.NAMED_ELEMENT__NAME)) {
				prependNamedElementName(id, container)
			} else {
				prependContainingFeatureName(id, container)
			}
			container = container.eContainer()
		}
		return id.toString()
	}

	def private static void prependNamedElementName(StringBuilder id, EObject container) {
		var String name = (container.eGet(TypesPackage.Literals.NAMED_ELEMENT__NAME) as String)
		if (name !== null) {
			id.insert(0, ID_SEPARATOR)
			id.insert(0, name)
		}
	}

	def private static void prependContainingFeatureName(StringBuilder id, EObject container) {
		var EStructuralFeature feature = container.eContainingFeature()
		if (feature !== null) {
			var String name
			if (feature.isMany()) {
				var Object elements = container.eContainer().eGet(feature)
				var int index = 0
				if (elements instanceof BasicEList) {
					var BasicEList<?> elementList = (elements as BasicEList<?>)
					index = elementList.indexOf(container)
				}
				name = feature.getName() + index
			} else {
				name = feature.getName()
			}
			id.insert(0, ID_SEPARATOR)
			id.insert(0, name)
		}
	}
}
