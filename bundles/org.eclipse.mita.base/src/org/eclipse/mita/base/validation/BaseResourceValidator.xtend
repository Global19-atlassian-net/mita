package org.eclipse.mita.base.validation

import org.eclipse.xtext.validation.ResourceValidatorImpl
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.validation.CheckMode
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.service.OperationCanceledError
import org.eclipse.mita.base.typesystem.infra.MitaBaseResource

class BaseResourceValidator extends ResourceValidatorImpl {
	
	override validate(Resource resource, CheckMode mode, CancelIndicator mon) throws OperationCanceledError {
		if(resource instanceof MitaBaseResource) {
			if(resource.latestSolution === null) {
				resource.collectAndSolveTypes(resource.contents.head);
			}
		}
		
		super.validate(resource, mode, mon)
	}
	
}